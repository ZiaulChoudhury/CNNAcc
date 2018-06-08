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
#define S 3

interface Store;
        method Action write(Vector#(Rate,DataType) vals, Bool _ready);
	method Action latchData;
        method Action read;
	method ActionValue#(Vector#(S,DataType)) flushtoDRAM(Int#(20) total_output);
        method Vector#(Rate,DataType) get;
	method Action clean;
	method Bit#(1) flusherReady;
	method ActionValue#(Bool) flushNext(Int#(20) total_output);
endinterface

(*synthesize*)
module mkStore(Store);

	BRAM_Configure cfg = defaultValue;
	Integer size = MaxR*MaxC/(Rate);
	cfg.allowWriteResponseBypass = False;
	cfg.memorySize = size;
	BRAM2Port#(UInt#(20), DataType) memory[Rate];
	Reg#(DataType) _cache[Rate];
	Reg#(UInt#(20)) rear <- mkReg(0);
	Reg#(UInt#(20)) front <- mkReg(0);
	Reg#(int) inFlush  <- mkReg(0);
	Reg#(Int#(20)) outFlush <- mkReg(0);
	FIFOF#(DataType) flusher[2];
	flusher[0] <-  mkSizedBRAMFIFOF(size);
	flusher[1] <-  mkSizedBRAMFIFOF(size);
	Reg#(int) clk <- mkReg(0);
	Reg#(Bool) flushOut <- mkReg(False); 
	Wire#(Bool)                                 _l0            <- mkWire;
	Wire#(Bool)                                 _l1            <- mkWire;
		
	for(int i= 0 ;i < fromInteger(Rate); i = i+1) begin
	 	memory[i]	<- mkBRAM2Server(cfg);
		_cache[i]	<- mkReg(0);
	end

	function BRAMRequest#(UInt#(20), DataType) makeRequest(Bool write, UInt#(20)  addr, DataType data);
        return BRAMRequest {
                write : write,
                responseOnWrite : False,
                address : addr,
                datain : data
        };
	endfunction

	rule _Clk;
			clk <= clk + 1;
	endrule
	
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
					for(int i = 0 ;i < fromInteger(Rate); i = i +1) begin
                                		flusher[i].enq(vals[i]);
					end
					inFlush <= inFlush + 1;
					flushOut <= True;
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

	method ActionValue#(Vector#(S,DataType)) flushtoDRAM(Int#(20) total_output);
			 Vector#(S,DataType) datas = newVector;
				
			 for(int i = 0 ;i < fromInteger(Rate); i = i +1) begin
					let d = flusher[i].first; flusher[i].deq;
					datas[i] = d;
			 end

			  if(outFlush >= total_output - 1 ) begin
                                datas[S-1] = 1;
                                outFlush <= 0;
                          end
                          else begin
                                datas[S-1] = 0;
                                outFlush <= outFlush + 1;
                          end

			$display(" flushing number %d ", outFlush );
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
		inFlush <= 0;
		flushOut <= False;
		_l0 <= True;
	endmethod

	method ActionValue#(Bool) flushNext(Int#(20) total_output)  if(flushOut == True); 
			if(outFlush >= total_output && flusher[0].notEmpty == False && flusher[1].notEmpty == False) begin
				flushOut <= False;
				outFlush <= 0;
                                return True;
			 end
                         else
                                return False;
	endmethod	

	method Bit#(1) flusherReady;
			 if(outFlush == 96 || flushOut == False) //flusher[0].notEmpty == False && flusher[1].notEmpty == False)
				return 1;
			 else
				return 0;
	endmethod
	
endmodule
endpackage
