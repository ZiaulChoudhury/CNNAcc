import BRAM::*;
import DefaultValue::*;
import FIFO::*;
import FixedPoint::*;
import datatypes::*;

#define WIDTH 512

interface FIFORand;
        method Action enq(DataType val, BramWidth c);
	method Action latchData;
        method Action deq(BramWidth c);
        method DataType get;
	method Action clean;
endinterface: FIFORand

(*synthesize*)
module mkBuffer(FIFORand);

	BRAM_Configure cfg = defaultValue;
	cfg.allowWriteResponseBypass = False;
	cfg.memorySize = WIDTH;
	BRAM2Port#(BramWidth, DataType) memory <- mkBRAM2Server(cfg);
	Reg#(DataType) _cache <- mkReg(0);

	function BRAMRequest#(BramWidth, DataType) makeRequest(Bool write, BramWidth  addr, DataType data);
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


	method Action enq(DataType data, BramWidth c);
			memory.portA.request.put(makeRequest(True, c, data));
	endmethod

	
	method Action deq(BramWidth c);
		memory.portB.request.put(makeRequest(False, c, 0));

	endmethod


	method DataType get;
		return _cache;
	endmethod
	
	method Action clean;
                        let d <- memory.portB.response.get;
                        _cache <= d;
              
        endmethod
	
endmodule: mkBuffer
