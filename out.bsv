package out;
import BRAM::*;
import DefaultValue::*;
import FIFO::*;
import FIFOF::*;
import pulse::*;
import BRAMFIFO::*;
import Vector::*;
import FixedPoint::*;
import datatypes::*;
import chunk::*;

#define Rate 1
#define S 2
#define SIZE 6300

interface Store;
        method Action write(Vector#(Rate,Bit#(128)) vals, Bool _ready);
	method Action latchData;
        method Action read;
	method ActionValue#(Vector#(S,Bit#(64))) flushtoDRAM(Int#(20) total_output);
        method Vector#(Rate,Bit#(128)) get;
	method Action clean;
	method ActionValue#(Bit#(1)) flusherReady;
endinterface

(*synthesize*)
module mkStore(Store);
	Reg#(BramWidth) rear <- mkReg(0);
	Reg#(BramWidth) front <- mkReg(0);
	Reg#(Bit#(128)) _cache[Rate];
	Reg#(int) clk <- mkReg(0);
	Reg#(Int#(20)) outFlush <- mkReg(0);
	Wire#(Bool)                                 _l0            <- mkWire;
	Wire#(Bool)                                 _l1            <- mkWire;
	Chunk memory[Rate];
		
	for(int i= 0 ;i < fromInteger(Rate); i = i+1) begin
	 	memory[i]	<- mkChunk;
		_cache[i]	<- mkReg(0);
	end

	rule _Clk;
			clk <= clk + 1;
	endrule
	
	(*mutually_exclusive = "cleanMemory, latchMemory" *)
	rule cleanMemory (_l0 == True);
		for(int i = 0 ;i < fromInteger(Rate); i = i +1) begin
                        memory[i].clean;
                end
	endrule
	
	rule latchMemory (_l1 == True);
			for(int i = 0 ;i < fromInteger(Rate); i = i +1) begin
                        memory[i].latch;
                	end

	endrule
	
	method Action latchData;
			_l1 <= True;
	endmethod


        method Action write(Vector#(Rate, Bit#(128)) vals, Bool _ready);	
			if(rear >= SIZE)
			rear <= 0;
			else begin
				if( _ready == True) begin
					for(int i = 0 ;i < fromInteger(Rate); i = i +1)
                                		memory[i].flush(vals[i]);
				end
				else begin	
					for(int i = 0 ;i < fromInteger(Rate); i = i +1) begin
                                	memory[i].write(vals[i], rear);
					end
					rear <= rear + 1;
				end
			end
	endmethod

	
	method Action read;
		if(front >= SIZE)
		front <= 0;
		else begin
		for(int i = 0 ;i < fromInteger(Rate); i = i +1)
                        memory[i].read(front);
		front <= front + 1;
		end
	endmethod

	method ActionValue#(Vector#(S,Bit#(64))) flushtoDRAM(Int#(20) total_output);
			 Vector#(S,Bit#(64)) datas = newVector;
			 for(int i = 0 ;i < fromInteger(Rate); i = i +1) begin
					let d <- memory[i].flushed;
					datas[i] = d;
			 end
			 if(outFlush >= total_output-1) begin
                                datas[S-1] = 1;
                                outFlush <= 0;
                          end
                          else begin
                                datas[S-1] = 0;
                                outFlush <= outFlush + 1;
                          end

		return datas;
	endmethod

	method Vector#(Rate,Bit#(128)) get;
		Vector#(Rate, Bit#(128)) datas = newVector;
		for(int i=0; i<fromInteger(Rate); i = i+1)
			datas[i] = memory[i].get;
		return datas;
	endmethod
	
	method Action clean;
		front <= 0;
		rear <= 0;
		_l0 <= True;
	endmethod

	method ActionValue#(Bit#(1)) flusherReady;
			 let f1 = memory[0]._Empty;
			 if(f1)
				return 1;
			 else
				return 0;
	endmethod
	
endmodule
endpackage
