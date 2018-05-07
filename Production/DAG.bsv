package DAG;
import BRam::*;
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

#define Roof 2
#define Depth 4
#define Filters 4
#define DW 8


#define DRAM 4
#define DWO 8
#define DEBUG 0 

interface Std;
        method Action sliceIn(Vector#(Roof,Bit#(64)) datas);
	method Action filter(Bit#(128) datas, Int#(10) fl, Int#(4) sl);
        method ActionValue#(Vector#(DWO,Bit#(16))) receive;
	method Action resetNet(Int#(12) sl, Bool pool, Int#(5) l, Int#(10) img, Int#(20) total_output);
	method Action resetDone;
	method Action probe;
	method ActionValue#(Bool) flushDone;
endinterface

(*synthesize*)
module mkDAG(Std);
		
		//####################################### INITS ####################################		
		FIFOF#(Bit#(64)) instream[2];
                FIFO#(Bit#(16)) forward[Filters][Roof];
		FIFOF#(DataType) _PartialProd[Filters][Roof];
		Reg#(Int#(12)) slice <- mkReg(0);
		Reg#(Int#(5))  layer <- mkReg(0);
		Reg#(Int#(20)) total_out <- mkReg(0);
		Pulse _stats[Filters];
		Reg#(DataType)  store[DW];
		Pulse	      _o[Filters]; 
		Pulse	      _r[Filters]; 
		Pulse	      _p[Filters];
		Reg#(Bit#(1))	_zp <- mkReg(0);
		Reg#(Bit#(1))   _z[Filters];
		Reg#(Bit#(64))  filters[Filters][9];
		Reg#(Bool) 	doPool <- mkReg(False);	
		Reg#(Bool) 	_reset <- mkReg(False);	
		Pool2		maxPools[Filters];
		Reg#(int) clk <- mkReg(0);
		Convolver stage <- mkConvolver;
		Store outSlice[Filters];
		Integer _depths[3] = {4,4,4};
		Reg#(int) c0[4];
                Reg#(Int#(8)) dr <- mkReg(0);
                for(int i=0 ;i<4; i = i+1) begin
                        c0[i] <- mkReg(0);
		end
		
		rule _clk;
			clk <= clk + 1;
		endrule

		for(int i=0; i< Filters; i = i+1) begin
				outSlice[i] <- mkStore;
				_stats[i] <- mkPulse;
		end
			
		for(int i=0; i< Filters; i = i+1) begin
			for(int j=0 ;j<9 ; j = j+1)
				filters[i][j] <- mkReg(0);
				
		end

		for(int k = 0; k<Filters; k = k + 1) begin
			_o[k] <- mkPulse;
			_p[k] <- mkPulse;
			_z[k] <- mkReg(0);
			_r[k] <- mkPulse;
		end
		
		for(int i = 0; i< DW; i = i+1)
				store[i] <- mkReg(0);
		
		for(int k = 0; k< Filters ; k = k+1) begin
			for(int i = 0 ;i< Roof; i = i+1)
				forward[k][i] <- mkFIFO;
		end

		for(int k = 0; k< Filters ; k = k+1) begin	
			maxPools[k] <- mkPool2;	
			for(int i=0;i<Roof; i = i+1) begin
				_PartialProd[k][i] <- mkSizedFIFOF(12);
			end
		end
	
              
		for(int i=0; i<Roof; i = i+1)
                        instream[i] <- mkFIFOF;

		//################################################################################

		rule __strideFetch;
			Vector#(Roof, Bit#(64)) _datas = newVector;
                        for(int i=0; i< Roof; i = i+1) begin
                                let d = instream[i].first; instream[i].deq;
				_datas[i] = unpack(d);
			end
                        stage.send(_datas);

		endrule
	
			
		rule convolution (doPool == False);
			Vector#(DW, DataType) datas = newVector;
                        	datas <- stage.receive;
				for(int i = 0; i< DW ; i = i + 1) begin
                                	store[i] <= datas[i];
                        	end
			_zp <= ~_zp;	
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
			_zp <= ~_zp;
		endrule


		for(int k = 0 ;k <Filters; k = k+1) begin
		rule outputSlice ((_z[k] ^ _zp) == 1);
			_z[k] <= _zp;
                        for(int i = 0; i< Roof ; i = i + 1) begin
                                let d = store[k*2 + i];
                                _PartialProd[k][i].enq(d);
                        end
			_o[k].send;
                endrule

		rule _readOutput (_reset == False);
			_o[k].ishigh;
			outSlice[k].read;
			_r[k].send;
		endrule
		
		rule _latchOutput (_reset == False);
			_r[k].ishigh;
			outSlice[k].latchData;
			_p[k].send;
		endrule

		rule _getOutput (_reset == False);
			_p[k].ishigh;
			Vector#(Roof,DataType) d = outSlice[k].get;
			Vector#(Roof,DataType) sums = newVector;
			Vector#(Roof,DataType) prods = newVector;	
			for(int i=0;i<Roof; i = i+1) begin
                                prods[i] = _PartialProd[k][i].first;
				_PartialProd[k][i].deq;
			end

			for (int i=0; i<Roof; i = i+1) begin
                                if(slice == 0) begin
                                sums[i] = prods[i];
				end
                                else begin
                                        let v = fxptTruncate(fxptAdd(prods[i], d[i]));
					sums[i] = v;
                                end
                        end
			
			_stats[k].send;	
			if(slice + Depth >= fromInteger(_depths[layer])) begin
				outSlice[k].write(sums, True);
			end
			else begin
				outSlice[k].write(sums, False);
			end


		endrule
		end
	
		for(Int#(8) _dram = 0; _dram < fromInteger(Filters) ; _dram = _dram + DRAM) 
		for(Int#(8) k=0; k<DRAM; k = k+1)
		rule _DRAMflush (dr == _dram/DRAM);
                                Vector#(3,DataType) d <- outSlice[k + _dram].flushtoDRAM(total_out);
                                for(UInt#(10) i=0; i<Roof; i = i+1)begin
                                        forward[k][i].enq(pack(d[i]));
                                end
				
				if(k==0) begin
					if(d[2] == 1) begin
						if(dr == fromInteger((Filters-DRAM)/DRAM))
                                        		dr <= 0;
                               	 		else
                                        		dr <= dr + 1;
					end
					
				end
                endrule
	
        	method ActionValue#(Vector#(DWO,Bit#(16))) receive;	
			Vector#(DWO,Bit#(16)) datas = newVector;
			for(UInt#(10) k=0; k<DRAM; k = k+1)
				for(UInt#(10) i=0; i<Roof; i = i+1)begin
					let d = forward[k][i].first;
					datas[2*k + i ] = d; 
					forward[k][i].deq;
				end
                        return datas;
                endmethod

		method Action sliceIn(Vector#(Roof,Bit#(64)) datas);
			for(int i = 0; i<Roof; i = i+1) begin
				instream[i].enq(datas[i]);
			end
		endmethod

		method Action resetNet(Int#(12) sl, Bool pool, Int#(5) l, Int#(10) img, Int#(20) total_output);
			layer <= l;
			total_out <= total_output;
			$display(" starting to process depth %d of layer %d", sl, l);
                      	stage.reboot(img);
			
			Vector#(Filters, Vector#(9, Bit#(64))) datas = newVector;
                        for(int i=0 ;i< Filters; i = i+1)
                                for(int j=0 ;j <9; j = j+1) begin
                                     datas[i][j] = filters[i][j];
				end
                        stage.weights(datas);
			doPool <= pool;
			slice <= sl;	
			 
			for(int i = 0; i < Filters; i= i+1) begin
                                	maxPools[i].clean;
					_o[i].clean;
					_p[i].clean;
					_r[i].clean;
				for(int k=0;k < Roof; k = k + 1) begin
					_PartialProd[i][k].clear;
				end
			end

			for(int i = 0;i<Roof ; i = i+1) begin
				instream[i].clear;
			end
			_reset <= True;

		endmethod

		method Action resetDone if (_reset == True);
                                stage.rebootDone;
				_reset <= False;		
				for(int i=0 ;i< Filters; i = i + 1)
					outSlice[i].clean;
		endmethod

		method ActionValue#(Bool) flushDone;
				Bit#(Filters) x = 0;
				if(layer == 3) begin
					for(int i=0 ;i< Filters; i = i + 1) begin
                                                let d <- outSlice[i].flusherReady;
						x[i] = 1 - d;
                                        end
				end
				else if(slice + Depth >= fromInteger(_depths[layer]))
                                        for(int i=0 ;i< Filters; i = i + 1) begin
                                                let d <-  outSlice[i].flusherReady;
						x[i] = 1 - d;
                                        end
				return x == 0;
		endmethod

		method Action filter(Bit#(128) datas, Int#(10) fl, Int#(4) sl);
					Vector#(2, Bit#(64)) data = unpack(datas);
                                        filters[fl][sl] <= data[0];
					filters[fl+1][sl] <= data[1];

                endmethod

		method Action probe;
				for(int i=0 ;i<Filters; i = i+1)
					_stats[i].ishigh;
		endmethod


          
endmodule

endpackage
