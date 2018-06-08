import BRAM::*;
import DefaultValue::*;
import FIFO::*;
import FixedPoint::*;
import datatypes::*;

#define MaxR 224
#define MaxC 224
#define Rate 2

interface MemOut;
        method Action write(DataType val);
	method Action latchData;
        method Action read;
        method DataType get;
	method Action clean;
endinterface: MemOut

(*synthesize*)
module mkMemOut(MemOut);

	BRAM_Configure cfg = defaultValue;
	cfg.allowWriteResponseBypass = False;
	Integer size = MaxR*MaxC/(Rate);
	cfg.memorySize = size;
	BRAM2Port#(UInt#(20), DataType) memory <- mkBRAM2Server(cfg);
	Reg#(DataType) _cache <- mkReg(0);
	Reg#(UInt#(20)) rear <- mkReg(0);
        Reg#(UInt#(20)) front <- mkReg(0);
	Wire#(Bool)                                 _l0            <- mkWire;
        Wire#(Bool)                                 _l1            <- mkWire;

	function BRAMRequest#(UInt#(20), DataType) makeRequest(Bool write, UInt#(20)  addr, DataType data);
        return BRAMRequest {
                write : write,
                responseOnWrite : False,
                address : addr,
                datain : data
        };
	endfunction


	(*mutually_exclusive = "cleanMemory, latchMemory" *)
        rule cleanMemory (_l0 == True);
                        let d <- memory.portB.response.get;
                        _cache <= d;
        endrule

        rule latchMemory (_l1 == True);
                        let d <- memory.portB.response.get;
                        _cache <= d;

        endrule
		
	method Action latchData;
				_l1 <= True;
	endmethod


	method Action write(DataType data);
			memory.portA.request.put(makeRequest(True, rear, data));
			rear <= rear + 1;
	endmethod

	
	method Action read;
		memory.portB.request.put(makeRequest(False, front, 0));
		front <= front + 1;

	endmethod

	method DataType get;
		return _cache;
	endmethod
	
	method Action clean;
			rear <= 0;
			front <= 0;
			_l0 <= True;
              
        endmethod
	
endmodule
