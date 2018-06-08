import BRAM::*;
import DefaultValue::*;
import FIFO::*;
import FixedPoint::*;
import TubeHeader::*;
import datatypes::*;

interface BFIFO;
        method Action enq(DataType val);
        method ActionValue#(DataType) deq;
	method Action startDeq;
endinterface: BFIFO

#define MaxR 112
#define MaxC 112
#define Rate 2

(*synthesize*)
module mkBramFifo(BFIFO);
	Wire#(Bool) deqStarted <- mkReg(False);
	BRAM_Configure cfg = defaultValue;
	cfg.allowWriteResponseBypass = False;
	Integer size = (MaxR*MaxC)/Rate;
	cfg.memorySize = size;
	BRAM2Port#(Int#(16), DataType) memory <- mkBRAM2Server(cfg);
	Reg#(Int#(16)) rear <- mkReg(0);
	Reg#(Int#(16)) front <- mkReg(0);

	Reg#(Bool) _enabDeq <- mkReg(False);
	Reg#(DataType) cache <- mkReg(0);
	FIFO#(DataType) send <- mkFIFO;

	function BRAMRequest#(Int#(16), DataType) makeRequest(Bool write, Int#(16) addr, DataType data);
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


	method Action startDeq;
		deqStarted <= True;
	endmethod

	method ActionValue#(DataType) deq;
		let d = send.first; send.deq;
		return d;
	endmethod

	
endmodule: mkBramFifo
