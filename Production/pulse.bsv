package pulse;

interface Pulse;
        method Action send;
        method Bool isvalid;
        method Action  ishigh;
	method Action  clean;
endinterface:Pulse

(*synthesize*)
module mkPulse(Pulse);

   Reg#(Bit#(1)) port[2]; 
	port[0] <- mkReg(0);
	port[1] <- mkReg(0);

   Reg#(Int#(3)) readCounter <- mkReg(0);
   Reg#(Int#(3)) writeCounter <- mkReg(0);
   Bool  valid =    (port[0] ==1 || port[1] ==1);

   method Bool isvalid;
		return valid;
   endmethod

   method Action send;

		port[writeCounter] <= 1;
		
		if(writeCounter == 1)
			writeCounter <= 0;
		else
			writeCounter <= writeCounter +1;
   endmethod

   method Action ishigh if(port[0] == 1 || port[1] ==1);

		if(readCounter ==  1)
			readCounter <= 0;
		else
			readCounter <= readCounter + 1;
		port[readCounter] <= 0;
		
   endmethod

   method Action clean;
		port[0] <= 0;
		port[1] <= 0;
		readCounter <= 0;
		writeCounter <= 0;
   endmethod

endmodule

endpackage

