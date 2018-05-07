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

#define MaxR 224
#define MaxC 224
#define Rate 2

interface Store;
        method Action write(Vector#(Rate,DataType) vals, Bool _ready);
	method Action latchData;
        method Action read;
	method ActionValue#(Vector#(3,DataType)) flushtoDRAM(Int#(20) total_output);
        method Vector#(Rate,DataType) get;
	method Action clean;
	method ActionValue#(Bit#(1)) flusherReady;
endinterface

(*synthesize*)
module mkStore(Store);

	//############################################## Data Structures ################################ 
	BRAM_Configure cfg = defaultValue;
	Integer size = ((MaxR)*(MaxC))/(Rate);
	cfg.allowWriteResponseBypass = False;
	cfg.memorySize = size;
	BRAM2Port#(BramWidth, DataType) memory[Rate];
	Reg#(DataType) _cache[Rate];
	Reg#(BramWidth) rear <- mkReg(0);
	Reg#(BramWidth) front <- mkReg(0);
	Reg#(Int#(20)) outFlush <- mkReg(0);
	FIFOF#(DataType) flusher[2];
	Reg#(Bit#(1)) p <- mkReg(0);
	Reg#(Bit#(1)) c <- mkReg(0);
	Reg#(Bit#(1)) flushIn <- mkReg(1);
	Wire#(Bool)                                 _l0            <- mkWire;
	Wire#(Bool)                                 _l1            <- mkWire;
		
	for(int i= 0 ;i < fromInteger(Rate); i = i+1) begin
	 	memory[i]	<- mkBRAM2Server(cfg);
		_cache[i]	<- mkReg(0);
		flusher[i] <- mkFIFOF;
	end

	function BRAMRequest#(BramWidth, DataType) makeRequest(Bool write, BramWidth  addr, DataType data);
        return BRAMRequest {
                write : write,
                responseOnWrite : False,
                address : addr,
                datain : data
        };
	endfunction

	//################################################################################################
	
	(*mutually_exclusive = "cleanMemory, latchMemory" *)
	rule cleanMemory (_l0 == True);
		for(int i = 0 ;i < fromInteger(Rate); i = i +1) begin
                        let d <- memory[i].portB.response.get;
                        _cache[i] <= d;
                end
	endrule
	
	rule latchMemory (_l1 == True);
			for(int i = 0 ;i < fromInteger(Rate); i = i +1) begin
                        let d <- memory[i].portB.response.get;
                        _cache[i] <= d;
                	end

	endrule
	
	method Action latchData;
			_l1 <= True;
	endmethod


        method Action write(Vector#(Rate,DataType) vals, Bool _ready);	
			if(rear >= fromInteger(size))
			rear <= 0;
			else begin
				if( _ready == True) begin
					flushIn <= 0;
					for(int i = 0 ;i < fromInteger(Rate); i = i +1) begin
                                		flusher[i].enq(vals[i]);
					end
				end
				else begin	
					for(int i = 0 ;i < fromInteger(Rate); i = i +1) begin
                                	memory[i].portA.request.put(makeRequest(True, rear, vals[i]));
					end
					rear <= rear + 1;
				end
			end
	endmethod

	
	method Action read;
		if(front >= fromInteger(size))
		front <= 0;
		else begin
		for(int i = 0 ;i < fromInteger(Rate); i = i +1)
                        memory[i].portB.request.put(makeRequest(False, front, 0));
		front <= front + 1;
		end
	endmethod

	method ActionValue#(Vector#(3,DataType)) flushtoDRAM(Int#(20) total_output);
			 	Vector#(3,DataType) datas = newVector;			
			 	for(int i = 0 ;i < fromInteger(Rate); i = i +1) begin
						let d = flusher[i].first; flusher[i].deq;
						datas[i] = d;
			 	end
		
			  if(outFlush >= total_output-1) begin
                            	datas[2] = 1;
                                outFlush <= 0;
				flushIn <= 1;
				p <= ~p;
			  end
			  else begin
				datas[2] = 0;
				outFlush <= outFlush + 1;
			  end
		return datas;
	endmethod

	method Vector#(Rate,DataType) get;
		Vector#(Rate, DataType) datas = newVector;
		for(int i=0; i<fromInteger(Rate); i = i+1)
			datas[i] = _cache[i];
		return datas;
	endmethod
	
	method Action clean;
		front <= 0;
		rear <= 0;
		flushIn <= 1;
		_l0 <= True;
	endmethod
	
	method ActionValue#(Bit#(1)) flusherReady;
			c <= p;
			return c ^ p | flushIn;
	endmethod
	
endmodule
endpackage
