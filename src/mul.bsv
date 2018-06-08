package mul;
import pulse::*;
import FixedPoint::*;
import datatypes::*;
import FIFOF::*;
//import fxpMul::*;

#define DEBUG 0

interface Mult;
        method Action a(DataType _a);
	method Action b(CoeffType _b);
	method ActionValue#(DataType) out;
	method Action clean;
endinterface

(*synthesize*)
module mkMult(Mult);
	FIFOF#(DataType) _aVal <- mkFIFOF;
	FIFOF#(CoeffType) _bVal <- mkFIFOF;
	Reg#(DataType)  av <- mkReg(0);
	Reg#(CoeffType) bv <- mkReg(0);
	Reg#(DataType)  cv <- mkReg(0);
	Pulse p0 <- mkPulse;
	Pulse p1 <- mkPulse;
	FIFOF#(DataType) outstream <- mkFIFOF;
	//FMUL mul <- mkfxpMul;
	Reg#(int) clk <- mkReg(0);
	
	
	rule _CLK;
		clk  <= clk + 1;
	endrule
	rule getInput;
		let a1 = _aVal.first; _aVal.deq;
                let b1 = _bVal.first; _bVal.deq;
		av <= a1;
		bv <= b1;
		p0.send;
	endrule
	rule compute;
		p0.ishigh;
		//mul.send(pack(av),pack(bv));
		let d = fxptTruncate(fxptMult(av,bv));
		outstream.enq(d);
	endrule

	/*rule getMultplication;
		let d <- mul.receive;
		cv <= d;
		p1.send;
			
	endrule

	rule sendResult;
		p1.ishigh;
		outstream.enq(cv);
	endrule*/

        method Action a(DataType _a);
		_aVal.enq(_a);
	endmethod

	method Action b(CoeffType _b);
		_bVal.enq(_b);
	endmethod

	
	method ActionValue#(DataType) out;
		let d = outstream.first; outstream.deq;
		return d;
	endmethod
		
	method Action clean;
                outstream.clear;
		//mul.clear;
		p1.clean;
		p0.clean;
		_aVal.clear;
		_bVal.clear;
        endmethod

endmodule
endpackage
