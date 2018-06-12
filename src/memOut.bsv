import BRAM::*;
import DefaultValue::*;
import FIFO::*;
import FixedPoint::*;
import datatypes::*;
import Vector::*;
	
#define MaxR 112
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
	BRAM2Port#(UInt#(20), Bit#(32)) memory <- mkBRAM2Server(cfg);
	Reg#(DataType) _cache <- mkReg(0);
	Reg#(DataType) cache <- mkReg(0);
	Reg#(UInt#(20)) rear <- mkReg(0);
        Reg#(UInt#(20)) front <- mkReg(0);
	
	Reg#(UInt#(1)) rPtr <- mkReg(0);
        Reg#(UInt#(1)) rPtr2 <- mkReg(0);
        Reg#(UInt#(1)) wPtr <- mkReg(0);

	Wire#(Bool)                                 _l0            <- mkWire;
        Wire#(Bool)                                 _l1            <- mkWire;

	function BRAMRequest#(UInt#(20), Bit#(32)) makeRequest(Bool write, UInt#(20)  addr, Bit#(32) data);
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
                        Vector#(2, DataType) dx = unpack(d);
                        _cache <= dx[0];

        endrule

        rule latchMemory (_l1 == True);
			
			rPtr2 <= rPtr2 + 1;
                        let d <- memory.portB.response.get;
                        Vector#(2, DataType) dx = unpack(d);
                        _cache <= dx[rPtr2];
        endrule
		
	method Action latchData;
				_l1 <= True;
	endmethod


	method Action write(DataType data);

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

	
	method Action read;
		
		rPtr <= rPtr + 1;
                memory.portB.request.put(makeRequest(False,front,0));

                if (front == fromInteger(size)-1)
                          front <= 0;
                else begin
                        if(rPtr == 1)
                          front <= front+1;
                end
	
	endmethod

	method DataType get;
		return _cache;
	endmethod
	
	method Action clean;
			rear <= 0;
			front <= 0;
			wPtr <= 0;
			rPtr <= 0;
			rPtr2 <= 0;
			_l0 <= True; 
        endmethod
	
endmodule
