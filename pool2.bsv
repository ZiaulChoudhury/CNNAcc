package pool2;
import FixedPoint::*;
import pulse::*;
import FIFO::*;
import datatypes::*;
import Real::*;
import Vector::*;

#define DEBUG 0

interface Pool2;
        method Action send(Bit#(256) data);
        method ActionValue#(Bit#(256)) reduced;
	method Action clean;
endinterface

(*synthesize*)
module mkPool2(Pool2);

   Pulse init[4];
   Pulse _l[4];
   Pulse _l1[4];
   FIFO#(Bit#(256)) outstream <- mkFIFO;
   Reg#(int) clk <- mkReg(0);
   Reg#(DataType) window[4][4];
   Reg#(DataType) result[4][2];
   Reg#(DataType) resultF[4][2];
  
   for(int i=0 ;i< 4; i = i + 1) begin
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
	for(int i=0 ;i<2; i = i+1)
		for(int j=0; j<2; j = j+1) begin
		rule level1;
				init[i*2 + j].ishigh;
				if (i == 0 && j == 0 )
				$display(" reduction started ");

				let a1 = window[i*2+0][j*2+0];
				let b1 = window[i*2+0][j*2+1];	
				let a2 = window[i*2+1][j*2+0];
				let b2 = window[i*2+1][j*2+1];	
				
				if(a1 > b1)
					result[2*i+j][0] <= a1;
				else
					result[2*i+j][0] <= b1;
				
				if(a2 > b2)
                                        result[2*i+j][1] <= a2;
                                else
                                        result[2*i+j][1] <= b2;
				_l[2*i+j].send;
					
   		endrule
		
		rule level2;
				_l[2*i+j].ishigh;
				let a1 = result[2*i+j][0];
				let b1 = result[2*i+j][1];
				$display(" comparing %d %d ", fxptGetInt(a1), fxptGetInt(b1));
				if(a1 > b1)
                                        resultF[2*i+j][0] <= a1;
                                else
                                        resultF[2*i+j][0] <= b1;
				
				_l1[2*i+j].send;

		endrule
		end

  rule collectValue;
		Vector#(16,DataType) dataOut = replicate(0);
			for(int i=0; i<4; i = i+1) begin
				_l1[i].ishigh;
				dataOut[i] = resultF[i][0];
			end
		outstream.enq(pack(dataOut));
  endrule

  method Action send(Bit#(256) data);
	Vector#(16,DataType) d = unpack(data);
	for(int i=0 ;i< 4; i = i + 1) begin
		init[i].send;
                for(int j=0; j<4; j = j+1) begin
			$display(" ------> %d ", fxptGetInt(d[i*4  + j]));
			window[i][j] <= d[i*4 + j];
		end
	end
  endmethod

  method ActionValue#(Bit#(256)) reduced;
	let d = outstream.first; outstream.deq;
	return d;
  endmethod 
  
  method Action clean;
                outstream.clear;
		for(int i=0; i<4; i = i+1) begin
			_l[i].clean;
			init[i].clean;
			_l1[i].clean;
		end
  endmethod

endmodule

endpackage

