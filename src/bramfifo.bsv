import BRAM::*;
import DefaultValue::*;
import FIFOF::*;
import FixedPoint::*;
import TubeHeader::*;
import datatypes::*;

interface BFIFO;
        method Action enq(DataType val);
        method ActionValue#(DataType) deq;
endinterface: BFIFO

#define MaxR 224
#define MaxC 224
#define Rate 2

(*synthesize*)
module mkBramFifo(BFIFO);
	Wire#(Bool) deqStarted <- mkReg(False);
	BRAM_Configure cfg = defaultValue;
	cfg.allowWriteResponseBypass = False;
	Integer size = (MaxR*MaxC)/Rate;
	cfg.memorySize = size;
	BRAM2Port#(Int#(20), DataType) memory <- mkBRAM2Server(cfg);
	Reg#(Int#(20)) rear <- mkReg(0);
	Reg#(Int#(20)) front <- mkReg(0);
	Reg#(DataType) cache <- mkReg(0);
	FIFOF#(DataType) send <- mkFIFOF;
	

	function BRAMRequest#(Int#(20), DataType) makeRequest(Bool write, Int#(20) addr, DataType data);
        return BRAMRequest {
                write : write,
                responseOnWrite : False,
                address : addr,
                datain : data
        };
	endfunction


	rule deqRequester (rear != front);
		memory.portB.request.put(makeRequest(False,front,0));
		if (front == fromInteger(size)-1)
                                        front <= 0;
                                else
                                        front <= front+1;
	endrule

	rule fillcache;
		let d <- memory.portB.response.get;
		send.enq(d);
	endrule

	method Action enq(DataType data);
		memory.portA.request.put(makeRequest(True, rear, data));
		if (rear == fromInteger(size)-1)
				rear <= 0; 
		else
			rear <= rear +1;
	
	endmethod

	method ActionValue#(DataType) deq;
		let d = send.first; send.deq;
		return d;
	endmethod
	

	
endmodule: mkBramFifo
