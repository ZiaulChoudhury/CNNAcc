package pool2;
import FixedPoint::*;
import pulse::*;
import FIFO::*;
import datatypes::*;
import Real::*;
import Vector::*;

#define DEBUG 0

interface Pool2;
        method Action send(Bit#(128) data);
        method ActionValue#(Bit#(128)) reduced;
	method Action clean;
endinterface

(*synthesize*)
module mkPool2(Pool2);

   Pulse init[2];
   Pulse _l[2];
   Pulse _l1[2];
   FIFO#(Bit#(128)) outstream <- mkFIFO;
   Reg#(int) clk <- mkReg(0);
   Reg#(DataType) window[2][4];
   Reg#(DataType) result[2][2];
   Reg#(DataType) resultF[2][2];
  
   for(int i=0 ;i< 2; i = i + 1) begin
		result[i][0] <- mkReg(0);
		result[i][1] <- mkReg(0);
		resultF[i][1] <- mkReg(0);
		resultF[i][0] <- mkReg(0);
		_l[i] <- mkPulse;
		_l1[i] <- mkPulse;
		init[i] <- mkPulse;
		for(int j=0; j<4; j = j+1)
			window[i][j] <- mkReg(0);
   end

	
   rule _CLK;
	clk <= clk + 1;
   endrule
	for(int i=0 ;i<2; i = i+1) begin
		rule level1;
				init[i].ishigh;		
				let a1 = window[0][i*2];
				let b1 = window[0][i*2+1];	
				let a2 = window[1][i*2];
				let b2 = window[1][i*2+1];	
				
				if(a1 > b1)
					result[i][0] <= a1;
				else
					result[i][0] <= b1;
				
				if(a2 > b2)
                                        result[i][1] <= a2;
                                else
                                        result[i][1] <= b2;
				_l[i].send;
					
   		endrule
		
		rule level2;
				_l[i].ishigh;
				let a1 = result[i][0];
				let b1 = result[i][1];
				if(a1 > b1)
                                        resultF[i][0] <= a1;
                                else
                                        resultF[i][0] <= b1;
				
				_l1[i].send;

		endrule
		end

  rule collectValue;
		Vector#(8,DataType) dataOut = replicate(0);
			for(int i=0; i<2; i = i+1) begin
				_l1[i].ishigh;
				dataOut[i] = resultF[i][0];
			end
		outstream.enq(pack(dataOut));
  endrule

  method Action send(Bit#(128) data);
	Vector#(8,DataType) d = unpack(data);
	for(int i=0 ;i< 2; i = i + 1) begin
		init[i].send;
                for(int j=0; j<4; j = j+1) begin
			window[i][j] <= d[i*4 + j];
		end
	end
  endmethod

  method ActionValue#(Bit#(128)) reduced;
	let d = outstream.first; outstream.deq;
	return d;
  endmethod 
  
  method Action clean;
                outstream.clear;
		for(int i=0; i<2; i = i+1) begin
			_l[i].clean;
			init[i].clean;
			_l1[i].clean;
		end
  endmethod

endmodule

endpackage

