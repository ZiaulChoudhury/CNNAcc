package BRam;
import bram::*;
import FIFO::*;
import pulse::*;
import datatypes::*;
import FIFOF::*;
import FixedPoint::*;
import Vector::*;

#define WIDTH 1024

interface Bram;
        method Action read(BramLength id, BramWidth col);
        method Action latch;
	method Action clean;
	method Bit#(64) get(BramLength id);
        method Action write(Bit#(64) data, BramLength id, BramWidth col);
endinterface:Bram


module mkBram#(Integer _B)(Bram);
	
	FIFORand slice[_B];
	for(int i=0;i<fromInteger(_B);i= i +1)
		slice[i] <- mkBuffer;

	method Action latch;
		      	for(BramLength i = 0; i<fromInteger(_B); i = i +1)
				slice[i].latchData;
	endmethod
	
	method  Bit#(64) get(BramLength id);
                        	let datas = slice[id].get;
                        return datas;
	endmethod
	
        method Action read(BramLength id,BramWidth col);
			if( col < WIDTH )
				slice[id].deq(col);
			else
				slice[id].deq(0);

	endmethod
	
        method Action write(Bit#(64) data, BramLength id, BramWidth col);
				slice[id].enq(data,col);
	endmethod

	method Action clean;
			for(int i=0; i< fromInteger(_B); i = i+1)
				slice[i].clean;
	endmethod

endmodule
endpackage
