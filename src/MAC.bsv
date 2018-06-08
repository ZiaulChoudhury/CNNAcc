package MAC;
import reduce::*;
import pulse::*;
import FIFO::*;
import datatypes::*;
import FixedPoint::*;
import Mult::*;

interface Mac;
		method Action a(DataType data, Int#(8) i);
		method Action b(CoeffType data, Int#(8) i); 
		method ActionValue#(DataType) result;
endinterface

module mkMAC#(Integer dim,Integer start, MultComplex _mComplex)(Mac);
	
	Reducer red <- mkReducer(dim);
	FIFO#(DataType) instreamA[dim];
	FIFO#(CoeffType) instreamB[dim];
	Reg#(DataType) valA[dim];
	Reg#(CoeffType) valB[dim];
	Reg#(DataType) valC[dim];
	Pulse	       _q[dim];
	Pulse	       _p[dim];
	

   	for(int i=0;i< fromInteger(dim) ; i = i+1) begin
        	instreamA[i] <- mkFIFO;
        	instreamB[i] <- mkFIFO;
		
		valA[i] <- mkReg(0);
		valB[i] <- mkReg(0);
		valC[i] <- mkReg(0);
		
		_q[i] <- mkPulse;
		_p[i] <- mkPulse;

   	end


	for(Int#(16) i = 0; i< fromInteger(dim) ; i = i+1) begin
		rule leaves;	
			_q[i].send;
			valA[i] <= instreamA[i].first; instreamA[i].deq;
                        valB[i] <= instreamB[i].first; instreamB[i].deq;
                endrule


		(* descending_urgency = "leafValues, getResultValue" *)
		rule leafValues;
			_q[i].ishigh;
			_mComplex.access(fromInteger(start)+i, valA[i], valB[i]);
		endrule

		rule getResultValue;
			let d <- _mComplex.result(fromInteger(start) + i);
			valC[i] <= d;
			_p[i].send;
		endrule

		rule send_values;
			_p[i].ishigh;						
			red.send(valC[i],truncate(i));
		endrule

	end

	method Action a(DataType data, Int#(8) i);
			instreamA[i].enq(data);
	endmethod
	
	method Action b(CoeffType data, Int#(8) i);
			instreamB[i].enq(data);
	endmethod
	
	method ActionValue#(DataType) result;
		let d <- red.reduced;
		return d;
	endmethod

endmodule
endpackage
