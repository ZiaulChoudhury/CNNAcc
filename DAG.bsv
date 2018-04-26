package DAG;
import TubeHeader::*;
import FixedPoint::*;
import datatypes::*;
import pulse::*;
import Vector::*;
import Stage::*;
import FIFO::*;
import FIFOF::*;
import out::*;

#define Roof 1
#define Filters 2
#define DW 2

 
#define DRAM 8
#define DWO 16
#define DEBUG 0 

interface Std;
        method Action sliceIn(Vector#(Roof,Bit#(64)) datas);
	method Action filter(Bit#(16) datas, Int#(10) fl, Int#(4) sl);
        method ActionValue#(Vector#(DWO,Bit#(16))) receive;
	method Action resetNet(Int#(12) sl, Bool pool, Int#(5) l, Int#(10) img, Int#(20) total_output);
	method Action resetDone;
	method Action probe;
	method Bool flushDone;
endinterface

(*synthesize*)
module mkDAG(Std);


		//####################################### INITS ####################################
		
		FIFOF#(Bit#(64)) instream[Roof];
                FIFO#(Bit#(16)) forward[Filters][Roof];
		FIFOF#(Bit#(128)) _PartialProd[Filters][Roof];
		Reg#(Int#(12)) slice <- mkReg(0);
		Reg#(int) fr <- mkReg(0);
		Reg#(Int#(5))  layer <- mkReg(0);
		Reg#(Int#(20)) total_out <- mkReg(0);
		Pulse _stats[Filters];
		Reg#(Bit#(128))  store[DW];
		Pulse	      _o[Filters]; 
		Pulse	      _r[Filters]; 
		Pulse	      _p[Filters];
		Pulse	      _fr <- mkPulse;
		Pulse	      _z[Filters];
		Reg#(Bit#(16))  filters[Filters][9];
		Reg#(UInt#(4)) c[Filters];
		Reg#(Bool) 	doPool <- mkReg(False);	
		Reg#(Bool) 	_reset <- mkReg(False);	
		Reg#(int) clk <- mkReg(0);
		Convolver stage <- mkStage;
		Store outSlice[Filters];
		Integer _depths[4] = {3,8,8,8};
                Reg#(Int#(8)) dr <- mkReg(0);
		Wire#(Bool)                                 _l[Filters];
		
		//#####################################################################################

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
			_z[k] <- mkPulse;
			_r[k] <- mkPulse;
			c[k]  <- mkReg(0);
			_l[k] <- mkWire;
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


		rule __sliceFetch;
			Vector#(Roof, DataType) _datas = newVector;
                        for(int i=0; i< Roof; i = i+1) begin
                                let d = instream[i].first; instream[i].deq;
				_datas[i] = unpack(d);
			end
			if(DEBUG == 1)
			$display("strideFetch|%d", clk);
                        stage.send(_datas);

		endrule
	
			
		rule convolution;
			Vector#(DW, Bit#(128)) datas = newVector;
                        	datas <- stage.receive;
			if(DEBUG == 1)
                                $display("conv|%d", clk);
			for(int i = 0; i< DW ; i = i + 1) begin
                                store[i] <= datas[i];
                        end
			for(int i=0; i< Filters ; i = i+1)
				_z[i].send;	
		endrule
		
		for(int k = 0 ;k <Filters; k = k+1) begin
		rule outputSlice;
			if(DEBUG == 1 && k==0 )
                            $display("AccumulateProducts|%d", clk);
			_z[k].ishigh;
                        for(int i = 0; i< Roof ; i = i + 1) begin
                                let d = store[k*Roof + i];
                                _PartialProd[k][i].enq(d);
                        end
			_o[k].send;
                endrule

		rule _readOutput (_reset == False);
			if(DEBUG == 1 && k==0 )
                            $display("ReadStoredProducts|%d", clk);
			_o[k].ishigh;
			outSlice[k].read;
			_r[k].send;
		endrule
		
		rule _latchOutput (_reset == False);
			if(DEBUG == 1 && k==0 )
                            $display("AccumulateProducts|%d", clk);
			_r[k].ishigh;
			outSlice[k].latchData;
			_p[k].send;
		endrule

		rule _getOutput (_reset == False);
			if(DEBUG == 1 && k==0 )
                            $display("AccumulateProducts|%d", clk);

			_p[k].ishigh;
			Vector#(Roof,Bit#(128)) d = outSlice[k].get;
			Vector#(Roof,Bit#(128)) sums = newVector;
			Vector#(Roof,Bit#(128)) prods = newVector;
	
			for(int i=0;i<Roof; i = i+1) begin
                                prods[i] = _PartialProd[k][i].first;
				_PartialProd[k][i].deq;
			end

			for (int i=0; i<Roof; i = i+1) begin
                                if(slice == 0) begin
                                sums[i] = prods[i];
				end
                                else begin
					Vector#(8, DataType)  p = unpack(prods[i]);
					Vector#(8, DataType) _d = unpack(d[i]);
					Vector#(8, DataType) _s = newVector;
				        for(int b = 0 ; b < 8 ; b = b + 1) begin
                                        	 let v = fxptTruncate(fxptAdd(p[i], _d[i]));
						_s[b] = v;
					end
					sums[i] = pack(_s);
                                end
                        end
			
			_stats[k].send;	
			if(slice == fromInteger(_depths[layer]-1)) begin
				outSlice[k].write(sums, True);
			end
			else begin
				outSlice[k].write(sums, False);
			end


		endrule
		end
	
		/*for(Int#(8) _dram = 0; _dram < fromInteger(Filters) ; _dram = _dram + DRAM) begin 		
		(*descending_urgency = " _DRAMflush, _DRAMout " *)
		
		for(Int#(8) k=0; k<DRAM; k = k+1)
		rule _DRAMflush (dr == _dram/DRAM);
			if(DEBUG == 1)
                            $display("Spilling|%d", clk);
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
                endrule*/
	
                /*rule _DRAMout(dr == _dram/DRAM);
			let d <- outSlice[_dram].flushNext(total_out);
			if(d) begin
				if(dr == fromInteger((Filters-DRAM)/DRAM))
					dr <= 0;
				else
                                	dr <= dr + 1;
                        end

                endrule*/
		//end
	
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
                      	stage.reboot(img,pool);
			Vector#(1200,CoeffType) datas = replicate(0);
                        for(int i=0 ;i< Filters; i = i+1)
                                for(int j=0 ;j <9; j = j+1) begin
                                     datas[i*9 + j] = unpack(filters[i][j]);
				end
                        stage.weights(datas);
			doPool <= pool;
			slice <= sl;	
			 
			for(int i = 0; i < Filters; i= i+1) begin
					_o[i].clean;
					_p[i].clean;
					_z[i].clean;
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

		method Bool flushDone;
				Bit#(9) x = 255;
				if(layer == 4) begin
					for(int i=0 ;i< Filters; i = i + 1) begin
                                                x[i] = outSlice[i].flusherReady;
                                        end
				end
				else if(slice == fromInteger(_depths[layer]-1))
                                        for(int i=0 ;i< Filters; i = i + 1) begin
                                                x[i] = outSlice[i].flusherReady;
                                        end
				UInt#(9) v = unpack(x);
				return v == 255;
		endmethod

		method Action filter(Bit#(16) datas, Int#(10) fl, Int#(4) sl);
                                        filters[fl][sl] <= datas;

                endmethod

		method Action probe;
				for(int i=0 ;i<Filters; i = i+1)
					_stats[i].ishigh;
		endmethod


          
endmodule

endpackage
