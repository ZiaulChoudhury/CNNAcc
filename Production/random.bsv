package random;
import FIFOF::*;

module mkRand();
	FIFOF#(int) _inQ <- mkFIFOF;
	Reg#(Bit#(1)) p0 <- mkReg(0);
	Reg#(Bit#(1)) c0 <- mkReg(0);
	Reg#(Bit#(1)) p1 <- mkReg(0);
        Reg#(Bit#(1)) c1 <- mkReg(0);
	Reg#(Bit#(1)) p2 <- mkReg(1);
        Reg#(Bit#(1)) c2 <- mkReg(0);
	Reg#(int) clk <- mkReg(0);

	rule _CLK;
		clk <= clk + 1;
	endrule


	(*descending_urgency = "_p0, _c0_p1, _c1" *)	
	rule _p0;
			_inQ.enq(12);
			p0 <= ~p0;
			$display(" rule _p0 at @clk %d ", clk);
	endrule

	rule _c0_p1((c0 ^ p0) == 1);
		c0 <= p0;
		p1 <= ~p1;
		$display(" rule _c0_p1 at @clk %d ", clk);
	endrule

	rule _c1 ((c1 ^ p1) == 1) ;
		c1 <= p1;
		p2 <= ~p2;
		$display(" rule _c1 at @clk %d ", clk);
		_inQ.enq(12);
		
	endrule

endmodule
endpackage
