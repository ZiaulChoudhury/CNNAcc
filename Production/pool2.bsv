package pool2;
import FIFO::*;
import datatypes::*;
import Vector::*;

interface Pool2;
        method Action send(Vector#(2,DataType) data);
        method ActionValue#(DataType) reduced;
	method Action clean;
endinterface

(*synthesize*)
module mkPool2(Pool2);

   // #################################### DATA Stuctructures ###############################
   FIFO#(DataType) outQ <- mkFIFO;
   Reg#(UInt#(4)) counter <- mkReg(0);
   Reg#(Bit#(1)) p0 <- mkReg(0);
   Reg#(Bit#(1)) c0 <- mkReg(0);
   Reg#(Bit#(1)) p1 <- mkReg(0);
   Reg#(Bit#(1)) c1 <- mkReg(0);
   Reg#(DataType) _reduction[4];
   Reg#(DataType) a <- mkReg(0);
   Reg#(DataType) b <- mkReg(0);
   _reduction[0] <- mkReg(0);  
   _reduction[1] <- mkReg(0);  
   _reduction[2] <- mkReg(0);  
   _reduction[3] <- mkReg(0);  
  // #######################################################################################

    rule l1 ((c0 ^ p0) == 1);
		c0 <= p0;
		DataType a1 = _reduction[0];
		DataType b1 = _reduction[1];
		DataType a2 = _reduction[2];
		DataType b2 = _reduction[3];
		
		if(a1 > b1)
			a <= a1;
		else
			a <= b1;
		
		if(a2 > b2)
			b <= a2;
		else
			b <= b2;

		p1 <= ~p1;
		
    endrule

    rule l2 ((c1 ^ p1) == 1);
                c1 <= p1;
		if(a > b)
			outQ.enq(a);
		else
			outQ.enq(b);
		
    endrule

   method Action send(Vector#(2,DataType) data);
	for(UInt#(4) i=0; i< 2; i = i +1)
		_reduction[i+counter] <= data[i];

	if(counter >= 2) begin
		p0 <= ~p0;
		counter <= 0;
	end
	else
		counter <= counter + 2;
   endmethod

  method ActionValue#(DataType) reduced;
	let d = outQ.first; outQ.deq;
	return d;
  endmethod 
  
  method Action clean;
                outQ.clear;
  endmethod

endmodule

endpackage

