package DAG;
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
import memOut::*;
import bramfifo::*;

#define BANKS 4
#define K 2
#define Filters 16
#define DW 32

#define DRAM 8
#define DEBUG 0 


interface Std;
        method Action sliceIn(Vector#(K,Bit#(64)) datas);
	method Action filter(Bit#(64) datas, Int#(10) fl, Int#(4) sl);
        method ActionValue#(Vector#(DRAM,Bit#(16))) receive;
	method Action resetNet(Int#(12) sl, Bool pool, Int#(5) l, Int#(10) img, Int#(20) total_output);
	method Action resetDone;
	method Action probe;
	method Action print;
	method ActionValue#(Bool) flushDone;
endinterface

(*synthesize*)
module mkDAG(Std);


		//####################################### INITS ####################################
		FIFOF#(Bit#(64)) instream[2];
                Reg#(Bool) _print <- mkReg(False);
		Reg#(Bit#(16)) _forward[DRAM];
                FIFO#(Bit#(16)) forward[DRAM];
		FIFOF#(DataType) _PartialProd[DW];
		//FIFOF#(DataType) flushQ[DW];
		BFIFO flushQ[DW];
		Reg#(Int#(12)) slice <- mkReg(0);
		Reg#(int) fr <- mkReg(0);
		Reg#(Int#(5))  layer <- mkReg(0);
		Reg#(Int#(20)) total_out <- mkReg(0);
		Reg#(Int#(20)) flushed[DW];
		Pulse _stats[DW];
		Reg#(DataType)  store[DW];
		Reg#(DataType)  _sum[DW];
		Pulse	      _o[DW]; 
		Pulse	      _r[DW]; 
		Pulse	      _p[DW];
		Pulse	      _z[DW];
		Pulse	      _s[DW];
		Pulse	      _s0[DW];
		Pulse	      _t[DRAM];
		Reg#(Bit#(64))  filters[Filters][9];
		Reg#(Bool) 	doPool <- mkReg(False);	
		Reg#(Bool) 	_reset <- mkReg(False);	
		Pool2		maxPools[Filters];
		Reg#(int) clk <- mkReg(0);
		Convolver stage <- mkStage;
		MemOut outSlice[DW];
		Integer _depths[4] = {8,32,16,16};
                Reg#(Int#(8)) dr[8];
                Reg#(Int#(8)) lx <- mkReg(0);

		for(int i=0 ;i<8; i = i + 1)
		 	dr[i] <- mkReg(0);
		
		//#####################################################################################			
		for(int i=0; i< Filters; i = i+1) begin
			for(int j=0 ;j<9 ; j = j+1)
				filters[i][j] <- mkReg(0);
				
		end

		for(int k = 0; k<DW; k = k + 1) begin
			_o[k] <- mkPulse;
			_p[k] <- mkPulse;
			_z[k] <- mkPulse;
			_r[k] <- mkPulse;
			_s[k] <- mkPulse;
			_s0[k] <- mkPulse;
			store[k] <- mkReg(0);
			_sum[k] <- mkReg(0);
			flushed[k] <- mkReg(0);
			outSlice[k] <- mkMemOut;
			_stats[k] <- mkPulse;
			flushQ[k] <- mkBramFifo;
			_PartialProd[k] <- mkSizedFIFOF(4);
		end
	
		for(int k = 0; k< Filters ; k = k+1) begin	
			maxPools[k] <- mkPool2;	
		end

		for(int k = 0; k<DRAM; k = k + 1) begin
			forward[k] <- mkFIFO;
			_t[k] <- mkPulse;
		end
	
              
		for(int i=0; i<K; i = i+1)
                        instream[i] <- mkFIFOF;


		rule __strideFetch;
			Vector#(K, Bit#(64)) _datas = newVector;
                        for(int i=0; i< K; i = i+1) begin
                                let d = instream[i].first; instream[i].deq;
				_datas[i] = d;
			end
                        stage.send(_datas);

		endrule
	
			
		rule convolution (doPool == False);
			Vector#(DW, DataType) datas = newVector;
                        	datas <- stage.receive;
			for(int i = 0; i< DW ; i = i + 1) begin
                                store[i] <= datas[i];
                        end
			
			for(int i=0; i< DW ; i = i+1)
				_z[i].send;	
		endrule
		
		rule maxpool2 (doPool == True);
					Vector#(DW, DataType) datas = newVector;
                                        datas <- stage.receive;
					if(DEBUG == 1)
                                		$display("conv|%d", clk);
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
			for(int i=0 ;i< DW ; i = i+1)
			_z[i].send;
		endrule


		for(int k = 0 ;k <DW; k = k+1) begin
		rule outputSlice;
			_z[k].ishigh;
                        _PartialProd[k].enq(store[k]);
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
			DataType d = outSlice[k].get;
			DataType prods = _PartialProd[k].first;
			_PartialProd[k].deq;
				DataType sums = 0;
                                if(slice == 0) begin
                                sums = prods;
				end
                                else begin
                                        let v = fxptTruncate(fxptAdd(prods, d));
					sums = v;
                                end


			_stats[k].send;	
			_sum[k] <= sums;
			if(slice >= fromInteger(_depths[layer]-4)) begin
				_s[k].send;
			end
			else begin
				_s0[k].send;
			end

		endrule

		rule _storeInMem;
			_s0[k].ishigh;
			outSlice[k].write(_sum[k]);
		endrule
		
		rule _flushOut;
			_s[k].ishigh;
			flushQ[k].enq(_sum[k]);
		endrule

		end
	
		for(Int#(8) _dram = 0; _dram < fromInteger(DW) ; _dram = _dram + DRAM)
                rule _DRAMflush (dr[lx] == _dram/DRAM);
				for (Int#(8) k=0; k<DRAM; k = k+1) begin
                                	let d <-  flushQ[k + _dram].deq;
                                	forward[k].enq(pack(d));
				end

				if(flushed[0] == 24641) begin
                                        	if(dr[lx] == fromInteger((DW-DRAM)/DRAM)) begin
                                                        lx <= lx + 1;
                                        	end
                                        	else
                                                        dr[lx] <= dr[lx] + 1;
					flushed[0] <= 0;
			
                                end
                                else
                                flushed[0] <= flushed[0] + 1;

                endrule
		
        	method ActionValue#(Vector#(DRAM,Bit#(16))) receive;	
			Vector#(DRAM,Bit#(16)) datas = newVector;
			for(UInt#(10) k=0; k<DRAM; k = k+1) begin
					let d = forward[k].first;
					datas[k] = d; 
					forward[k].deq;
			end
                        return datas;
                endmethod

		method Action sliceIn(Vector#(K,Bit#(64)) datas);
			for(int i = 0; i<K; i = i+1) begin
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
			 
			for(int i = 0; i < DW; i= i+1) begin
					_o[i].clean;
					_p[i].clean;
					_z[i].clean;
					_r[i].clean;
					_s[i].clean;
					_s0[i].clean;
					_PartialProd[i].clear;
			end

			for(int i = 0;i<DRAM; i = i + 1)
				_t[i].clean;
			for(int i=0;i<Filters; i = i + 1)
				maxPools[i].clean;
			for(int i = 0;i<K ; i = i+1) begin
				instream[i].clear;
			end
			_reset <= True;
		endmethod

		method Action resetDone if (_reset == True);
                                stage.rebootDone;	
					if(_print == True)
						stage.print;
				_reset <= False;		
				for(int i=0 ;i<DW; i = i + 1)
					outSlice[i].clean;
		endmethod

		method ActionValue#(Bool) flushDone;
                                if(slice >= fromInteger(_depths[layer]-4) && layer > 0)	
					if(dr[layer-1] == fromInteger((DW-DRAM)/DRAM)) begin
						return True;
					end
					else
					return False;
				else
				return True;

		endmethod

		method Action filter(Bit#(64) datas, Int#(10) fl, Int#(4) sl);
                                        filters[fl][sl] <= datas;

                endmethod

		method Action probe;
				for(int i=0 ;i<DW; i = i+1)
					_stats[i].ishigh;
		endmethod

		method Action print;

				_print <= True;
		endmethod


          
endmodule

endpackage
