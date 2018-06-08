package conv;
import pulse::*;
import datatypes::*;
import mul::*;
import reduce3::*;
import Vector::*;

interface Conv;
		method Action put(Vector#(9,DataType) wb);
		method Action filter(Vector#(9, CoeffType) coeff);
		method ActionValue#(DataType) get;
		method Action clean;
endinterface

(*synthesize*)
module mkConv(Conv);
Mult _PE[9];
Reg#(DataType) res[9];
Pulse p <- mkPulse;
Reducer3 red <- mkReducer3;
Reg#(CoeffType) coeffs[9];

	for( int i = 0;i <9 ; i = i + 1) begin
		_PE[i] <- mkMult;
		res[i] <- mkReg(0);
		coeffs[i] <- mkReg(0);
	end


	rule multiplies;
			for(int i=0 ;i<9; i = i+1) begin
				let d <- _PE[i].out;
				res[i] <= d;
			end
			p.send;
	endrule
	
	rule accumulate;
			p.ishigh;
			Vector#(9, DataType) d = newVector;
			for(int i=0; i<9; i = i+1)
				d[i] = res[i];
			red.send(d);
	endrule

	
method ActionValue#(DataType) get;
		let d <- red.reduced;
		return d;
endmethod

method Action put(Vector#(9,DataType) wb);
	  for(int i=0 ;i<9; i = i+1) begin
	 	_PE[i].a(wb[i], False);
         	_PE[i].b(coeffs[i]);
	  end
endmethod

method Action filter(Vector#(9,CoeffType) coeff);
		for(int i=0; i<9 ; i = i + 1)
			coeffs[i] <= coeff[i];
endmethod

method Action clean;
		for(int i=0 ;i<9; i = i+1)
				_PE[i].clean;
		p.clean;
		red.clean;
endmethod


endmodule
endpackage
