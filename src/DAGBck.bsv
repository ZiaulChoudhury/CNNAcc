package DAG;
import BRam::*;
import TubeHeader::*;
import FixedPoint::*;
import datatypes::*;
import bram::*;
import pulse::*;
import Vector::*;
import Stage::*;
import FIFO::*;
import FIFOF::*;
import pool2::*;
import out::*;
import reduce3::*;


import "BDPI" function Action initialize_image();
import "BDPI" function Int#(32) readPixel1(Int#(32) ri, Int#(32) cj, Int#(32) ch);
import "BDPI" function Int#(32) readPixel2(Int#(32) ri, Int#(32) cj, Int#(32) ch);

#define BANKS 4
#define K 2
#define Filters 8
#define DW 16
#define DRAM 1
#define DWO 2  


interface Std;
        method Action sliceIn(Vector#(K,Bit#(16)) datas);
	method Action filter(Vector#(3,Bit#(16)) datas);
	method Action filterFetch;
        method ActionValue#(Vector#(DWO,Bit#(16))) receive;
	method Action resetNet(Int#(12) sl, Bool pool, Int#(5) l, UInt#(9) img);
	method Action resetDone;
endinterface

(*synthesize*)
module mkDAG(Std);


		//####################################### INITS ####################################
		FIFOF#(Int#(9)) instream[2];
                FIFOF#(Bit#(16)) forward[DRAM][K];
		FIFOF#(DataType) _PartialProd[Filters][K];
		Reg#(Int#(12)) slice <- mkReg(0);
		Reg#(Int#(5))  layer <- mkReg(0);
		Reg#(Bool)  flushing <- mkReg(False);
		Reg#(Bit#(1)) bufferIndex <- mkReg(0);
		Reg#(Bool)    bufferEmpty[2];
		Reg#(int) flushCount <- mkReg(0);
		Reg#(Bool) _reset <- mkReg(False);
		Reg#(int) imgDim <- mkReg(24642);
		Reg#(BramWidth) flushedSlices <- mkReg(0);
		Pulse flatch[DRAM];
		Pulse flush <- mkPulse;
		Reg#(DataType)  store[DW];
		Pulse	      _o[Filters]; 
		Pulse	      _p[Filters];
		Pulse	      _z <- mkPulse;
		Reg#(Bit#(16))  filters[2][Filters][9];
		Reg#(UInt#(4)) c[Filters];
		Reg#(Bool) 	doPool <- mkReg(False);	
		Pool2		maxPools[Filters];
		Reg#(int) clk <- mkReg(0);
		Convolver stage <- mkStage;
		Store outSlice[2][Filters];
		Integer _depths[5] = {3,64,64,16,16};
		//#####################################################################################

		rule _clk;
			clk <= clk + 1;
		endrule

		for(int k = 0; k<2; k = k+1) begin
			bufferEmpty[k] <- mkReg(True);
			for(int i=0; i< Filters; i = i+1) begin
				outSlice[k][i] <- mkStore;
				for(int j=0 ;j<9 ; j = j+1)
					filters[k][i][j] <- mkReg(0);
				
			end
		end
		
		
		for(int k = 0; k<Filters; k = k + 1) begin
			_o[k] <- mkPulse;
			_p[k] <- mkPulse;
			c[k]  <- mkReg(0);
		end
		
		for(int i = 0; i< DW; i = i+1)
				store[i] <- mkReg(0);
		
		for(int k = 0; k< DRAM ; k = k+1) begin
			flatch[k] <- mkPulse;
			for(int i = 0 ;i< K; i = i+1)
				forward[k][i] <- mkFIFOF;
		end

		for(int k = 0; k< Filters ; k = k+1) begin	
			maxPools[k] <- mkPool2;	
			for(int i=0;i<K; i = i+1) begin
				_PartialProd[k][i] <- mkSizedFIFOF(12);
			end
		end
	
              
		for(int i=0; i<K; i = i+1)
                        instream[i] <- mkFIFOF;


		rule __strideFetch;
			Vector#(K, DataType) _datas = newVector;
                        for(int i=0; i< K; i = i+1) begin
                                let d = instream[i].first; instream[i].deq;
				_datas[i] = fromInt(d);
			end
                        stage.send(_datas);

		endrule
	
			
		rule convolution (doPool == False);
			Vector#(DW, DataType) datas = newVector;
                        	datas <- stage.receive;
			for(int i = 0; i< DW ; i = i + 1) begin
                                store[i] <= datas[i];
                        end
			_z.send;	
		endrule
		
		rule maxpool2 (doPool == True);
					Vector#(DW, DataType) datas = newVector;
                                        datas <- stage.receive;
					for (int i = 0 ; i < DW ; i = i+2) begin
                                                        Vector#(2,DataType)  _pool = newVector;
                                                                for(int j = 0 ; j<2; j = j+1)
                                                                        _pool[j] = datas[i+j];
                                                        maxPools[i/2].send(_pool);
					end
                                              
		endrule

		rule summation (doPool == True);
			for(int i = 0; i< Filters ; i = i + 1) begin
				let d <- maxPools[i].reduced;
				store[2*i] <= d;
				store[2*i +1] <= 0;
				
			end
			_z.send;
		endrule


		for(int k = 0 ;k <Filters; k = k+1) begin
		rule outputSlice;
			if(k==0)
				_z.ishigh;
                        for(int i = 0; i< K ; i = i + 1) begin
                                let d = store[k*2 + i];
                                _PartialProd[k][i].enq(d);
                        end
			_o[k].send;
                endrule

		rule _readOutput;
			_o[k].ishigh;
			outSlice[bufferIndex][k].read;
		endrule
		
		rule _latchOutput;
			outSlice[bufferIndex][k].latchData;
			_p[k].send;
		endrule

		rule _getOutput;
			_p[k].ishigh;
			Vector#(K,DataType) d = outSlice[bufferIndex][k].get;
			Vector#(K,DataType) sums = newVector;
			Vector#(K,DataType) prods = newVector;
	
			for(int i=0;i<K; i = i+1) begin
                                prods[i] = _PartialProd[k][i].first;
				_PartialProd[k][i].deq;
			end

			for (int i=0; i<K; i = i+1) begin
                                if(slice == 0) begin
                                sums[i] = prods[i];
				end
                                else begin
                                        let v = fxptTruncate(fxptAdd(prods[i], d[i]));
                                        sums[i] = v;
                                end
                        end
			
			if( k== 0) begin
				if(slice == fromInteger(_depths[layer]))
					bufferEmpty[bufferIndex] <= False;
			
				if(slice == 0 && bufferEmpty[~bufferIndex] == False)
					flush.send;
			end

			outSlice[bufferIndex][k].write(sums);

		endrule
		end

			
		rule flusherStart;
			flush.ishigh;
			if(flushCount == imgDim) begin
				if(flushedSlices == Filters) begin
					bufferEmpty[~bufferIndex] <= True; 
				end	
				else begin
					flushedSlices <= flushedSlices + DRAM;
					flushCount <= 0;
				end
			end
			else
				flushCount <= flushCount  + 1;

			for(int i=0; i<DRAM; i = i + 1)
				outSlice[~bufferIndex][i].read;

			
		endrule
		
		rule flusherLatch (_reset == False);
			for(int j=0 ;j< DRAM; j = j+1) begin
				outSlice[~bufferIndex][j].latchData;
				flatch[j].send;
			end
				
		endrule

		rule flushGet;
			Vector#(K,DataType) datas = newVector;
			for(int j=0 ;j< DRAM; j = j+1) begin
                                flatch[j].ishigh;
                                datas = outSlice[1-bufferIndex][j].get;
				for(int i = 0; i< K; i = i + 1)
					forward[j][i].enq(pack(datas[i]));
                        end

		endrule
			
        	method ActionValue#(Vector#(DWO,Bit#(16))) receive;
			Vector#(DWO,Bit#(16)) datas = newVector;
			for(int k=0; k<DRAM; k = k+1)
				for(int i=0; i<K; i = i+1)begin
                        		datas[2*k + i] = forward[k][i].first; 
					forward[k][i].deq;
				end
                        return datas;
                endmethod

		method Action sliceIn(Vector#(K,Bit#(16)) datas);
			for(int i = 0; i<K; i = i+1) begin
				Bit#(9) x = truncate(datas[i]);
				instream[i].enq(unpack(x)); 
			end
		endmethod

		method Action resetNet(Int#(12) sl, Bool pool, Int#(5) l, UInt#(9) img);
			layer <= l;
                      	stage.reboot(img);
			doPool <= pool;
			slice <= sl;
			_z.clean;	

			
			for(int i = 0; i < DRAM; i= i+1)
				for(int k=0;k < K; k = k + 1)
					forward[i][k].clear;
		
			for(int i = 0; i < Filters; i= i+1) begin
                                	maxPools[i].clean;
					_o[i].clean;
					_p[i].clean;
				for(int k=0;k < K; k = k + 1) begin
					_PartialProd[i][k].clear;
				end
			end

			for(int i = 0;i<K ; i = i+1) begin
				instream[i].clear;
			end
			
			_reset <= True;
		
		endmethod

		method Action resetDone if (((slice == 0 && bufferEmpty[0] || bufferEmpty[1]) || slice > 0)) ;
                                stage.rebootDone;			
		endmethod


          
endmodule

endpackage
