import BRAM::*;
import DefaultValue::*;
import FIFOF::*;
import FixedPoint::*;
import TubeHeader::*;
import datatypes::*;
import Vector::*;

interface BFIFO;
        method Action enq(DataType val);
        method ActionValue#(DataType) deq;
endinterface: BFIFO

#define MaxR 112
#define MaxC 224
#define Rate 2

(*synthesize*)
module mkBramFifo(BFIFO);
	Wire#(Bool) deqStarted <- mkReg(False);
	BRAM_Configure cfg = defaultValue;
	cfg.allowWriteResponseBypass = False;
	Integer size = (MaxR*MaxC)/Rate;
	cfg.memorySize = size;
	BRAM2Port#(Int#(20), Bit#(32)) memory <- mkBRAM2Server(cfg);
	Reg#(Int#(20)) rear <- mkReg(0);
	Reg#(Int#(20)) front <- mkReg(0);
	FIFOF#(DataType) send <- mkFIFOF;

	Reg#(UInt#(1)) rPtr <- mkReg(0);
	Reg#(UInt#(1)) rPtr2 <- mkReg(0);
	Reg#(UInt#(1)) wPtr <- mkReg(0);
	Reg#(DataType) cache <- mkReg(0);

	function BRAMRequest#(Int#(20), Bit#(32)) makeRequest(Bool write, Int#(20) addr, Bit#(32) data);
        return BRAMRequest {
                write : write,
                responseOnWrite : False,
                address : addr,
                datain : data
        };
	endfunction


	rule deqRequester (rear != front);
		
		rPtr <= rPtr + 1;
		memory.portB.request.put(makeRequest(False,front,0));
		
		if (front == fromInteger(size)-1)
                          front <= 0;
                else begin
			if(rPtr == 1) 
                          front <= front+1;
		end
	endrule

	rule fillcache;
		rPtr2 <= rPtr2 + 1;
		let d <- memory.portB.response.get;
		Vector#(2, DataType) dx = unpack(d);
		send.enq(dx[rPtr2]);
	endrule

	method Action enq(DataType data);
		Vector#(2, DataType) d = newVector;
		wPtr <= wPtr + 1;	

		if(wPtr == 0) begin
			cache <= data;
			d[0] = data;
		end
		else begin
			d[0] = cache;
			d[1] = data;
		end
			
		memory.portA.request.put(makeRequest(True, rear, pack(d)));
		
		if (rear == fromInteger(size)-1)
				rear <= 0; 
		else begin
			if(wPtr == 1)
				rear <= rear +1;
		end
	
	endmethod

	method ActionValue#(DataType) deq;
		let d = send.first; send.deq;
		return d;
	endmethod
	

	
endmodule: mkBramFifo
