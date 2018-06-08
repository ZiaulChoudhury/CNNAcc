package pool3;
import FixedPoint::*;
import pulse::*;
import FIFO::*;
import datatypes::*;
import Real::*;
import Vector::*;

interface Pool3;
        method Action send(Vector#(9,DataType) data);
        method ActionValue#(DataType) reduced;
endinterface

(*synthesize*)
module mkPool3(Pool3);

   Pulse init <- mkPulse;
   FIFO#(DataType) outstream <- mkFIFO;
   Integer paddedSize  = 16; 
   Integer steps = 4;

   Reg#(DataType) _reductionTree[steps+1][paddedSize];
   for(int i=0; i< fromInteger(steps)+1; i = i + 1)
	for(int j=0; j< fromInteger(paddedSize); j = j+1)
		_reductionTree[i][j] <- mkReg(0);

   Pulse _redPulse[steps+1];

   for(int i=0;i< fromInteger(steps)+1; i = i+1)
	_redPulse[i] <- mkPulse;

   Int#(10) powers[8];

   powers[0] = 2;
   powers[1] = 4;
   powers[2] = 8;
   powers[3] = 16;
   powers[4] = 32;
   powers[5] = 64;
   powers[6] = 128;
   powers[7] = 256;

	for(int l=0; l<fromInteger(steps); l = l + 1) 
   	rule level;
		_redPulse[l].ishigh;
		for(Int#(10) i=0;i < fromInteger(paddedSize)/powers[l]; i = i +1) begin
                        DataType a = _reductionTree[l][i]; 
			Datatype b = _reductionTree[l][fromInteger(paddedSize)/powers[l] + i];
			if(a>b)
				_reductionTree[l+1][i] <= a;
			else
				_reductionTree[l+1][i] <= b;
		end
                _redPulse[l+1].send;
   	endrule

  rule collectValue;
		_redPulse[steps].ishigh;
		let d = _reductionTree[steps][0];
		outstream.enq(d);
  endrule

   method Action send(Vector#(9,DataType) data);
	for(int i=0; i< 9; i = i +1)
		_reductionTree[0][i] <= data[i];
	_redPulse[0].send;
   endmethod

  method ActionValue#(DataType) reduced;
	let d = outstream.first; outstream.deq;
	return d;
  endmethod 

endmodule

endpackage

