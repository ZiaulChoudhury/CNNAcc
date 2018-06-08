package Dummy;
import out::*;
import DAG::*; 

module mkDummy(Empty);

		Reg#(Bit#(1)) r <- mkReg(1);
		rule check;
			$display(" %d ", ~r);
			$finish(0);
		endrule	
endmodule

endpackage
