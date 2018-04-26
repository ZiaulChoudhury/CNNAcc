package chunk;
import BRAM::*;
import DefaultValue::*;
import FIFO::*;
import FIFOF::*;
import pulse::*;
import BRAMFIFO::*;
import Vector::*;
import FixedPoint::*;
import datatypes::*;

#define SIZE 3200

interface Chunk;
	method Action write(Bit#(128) values, BramWidth index);	
	method Action read(BramWidth c);	
	method Action latch;
	method Bit#(128) get;
	method Action clean;	
	method Action flush(Bit#(128) data);
	method ActionValue#(Bit#(64)) flushed(Int#(20) total_output);
	method Bool _Empty;
endinterface

(*synthesize*)
module mkChunk(Chunk);
	BRAM_Configure cfg = defaultValue;
	cfg.allowWriteResponseBypass = False;
	cfg.memorySize = SIZE;
	BRAM2Port#(BramWidth, Bit#(64)) block[2]; 
	Reg#(Bit#(64)) _cache[2];
	Reg#(Bool) fl <- mkReg(False);
	FIFOF#(Bit#(64)) flusher[2];
	Wire#(Bool) _f[2];	
	Reg#(Int#(8)) flushCounter <- mkReg(0); 
	Reg#(Int#(20)) outFlush <- mkReg(0);
	Wire#(Bit#(64))                                 _dataWire            <- mkWire;

	function BRAMRequest#(BramWidth, Bit#(64)) makeRequest(Bool write, BramWidth  addr, Bit#(64) data);
        return BRAMRequest {
                write : write,
                responseOnWrite : False,
                address : addr,
                datain : data
        };
	endfunction

	
	for(int i=0; i<2; i = i+1) begin
		block[i] <- mkBRAM2Server(cfg);
		_cache[i] <- mkReg(0);
		flusher[i] <-  mkSizedBRAMFIFOF(SIZE);
		_f[i] <- mkWire;
	end

		
	for(Int#(8) i=0; i< 2; i = i+1)
                rule deqFlusher(flushCounter == i);
                        _dataWire <= flusher[i].first; flusher[i].deq;
                endrule


	method Bool _Empty;
			return fl && !flusher[1].notEmpty;
	endmethod

		
	method ActionValue#(Bit#(64)) flushed(Int#(20) total_output);

			Bit#(64) data = 0;	
			if(flushCounter == 1)
				flushCounter <= 0;
			else
				flushCounter <= flushCounter + 1;
			data = extend(_dataWire);	
			return data;		
	endmethod
	
	
	method Action flush(Bit#(128) data);
			fl <= True;
			Vector#(2, Bit#(64)) d = unpack(data);
			for(int i=0; i<2; i = i+1) begin
				Vector#(4, DataType) x = unpack(d[i]);
				flusher[i].enq(d[i]);
			end
	endmethod
	
	method Bit#(128) get;
			Vector#(2, Bit#(64)) d = newVector;
			for(int i=0 ;i<2; i = i + 1)
				d[i] = _cache[i];
			return pack(d);
	endmethod	
	
	method Action latch;
		for(int i=0 ;i<2; i = i + 1) begin
			 let d <- block[i].portB.response.get;
			 _cache[i] <= d;
		end
	endmethod
	
	method Action read(BramWidth c);
		for(int i=0 ;i<2; i = i + 1)
                        block[i].portB.request.put(makeRequest(False, c, 0));
	endmethod

	method Action write(Bit#(128) values, BramWidth index);
		Vector#(2, Bit#(64)) data = unpack(values);
		for(int i=0 ;i<2; i = i + 1)
			 block[i].portA.request.put(makeRequest(True, index, data[i]));
	endmethod	


	method Action clean;
		fl <= False;
		for(int i=0 ;i<2; i = i + 1) begin
			 let d <- block[i].portB.response.get;
                        _cache[i] <= d;
		end
	endmethod	

endmodule
endpackage
