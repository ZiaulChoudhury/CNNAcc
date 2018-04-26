import BRAM::*;
import DefaultValue::*;
import FIFO::*;
import FixedPoint::*;
import datatypes::*;

#define WIDTH 512

interface Buffer;
        method Action enq(Bit#(64) val, BramWidth c);
	method Action latchData;
        method Action deq(BramWidth c);
        method Bit#(64) get;
	method Action clean;
endinterface

(*synthesize*)
module mkBuffer(Buffer);

	BRAM_Configure cfg = defaultValue;
	cfg.allowWriteResponseBypass = False;
	cfg.memorySize = WIDTH;
	BRAM2Port#(BramWidth, Bit#(64)) memory <- mkBRAM2Server(cfg);
	Reg#(Bit#(64)) _cache <- mkReg(0);

	function BRAMRequest#(BramWidth, Bit#(64)) makeRequest(Bool write, BramWidth  addr, Bit#(64) data);
        return BRAMRequest {
                write : write,
                responseOnWrite : False,
                address : addr,
                datain : data
        };
	endfunction
	
	method Action latchData;
		let d <- memory.portB.response.get;
		_cache <= d;
	endmethod


	method Action enq(Bit#(64) data, BramWidth c);
			memory.portA.request.put(makeRequest(True, c, data));
	endmethod

	
	method Action deq(BramWidth c);
		memory.portB.request.put(makeRequest(False, c, 0));

	endmethod


	method Bit#(64) get;
		return _cache;
	endmethod
	
	method Action clean;
                        let d <- memory.portB.response.get;
                        _cache <= d;
              
        endmethod
	
endmodule: mkBuffer
