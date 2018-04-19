package TB2;
import conv36::*;
import TubeHeader::*;
import FixedPoint::*;
import datatypes::*;
import pulse::*;
import Vector::*;
import FIFO::*;

import "BDPI" function Action initialize_image();
import "BDPI" function UInt#(32) readPixel1(UInt#(32) ri, UInt#(32) cj, UInt#(32) ch);
import "BDPI" function UInt#(32) readPixel2(UInt#(32) ri, UInt#(32) cj, UInt#(32) ch);

#define IMG 16

(*synthesize*)

module mkTB2();

		Reg#(int) clk <- mkReg(0);
		Reg#(int) rows  <- mkReg(0);
       		Reg#(int) cols  <- mkReg(0);
		Reg#(Bool) init <- mkReg(True);
		Reg#(Bool) flagg <- mkReg(True);
		Reg#(UInt#(32)) c0 <- mkReg(0);
		Reg#(UInt#(32)) c1 <- mkReg(0);
		Reg#(UInt#(32)) test_reg <- mkReg(0);
		Conv36 cnnR <- mkConv36;

		rule init_rule (init) ;
                	init <= False;
      		endrule

		rule layerIn;
			Vector#(9, Bit#(64)) wb = newVector;
			for(int i=0; i<3; i = i+1)
				for(int j=0 ;j<3; j = j+1) begin
					Vector#(4, DataType) bundle = newVector;
					for(int k=0; k<2; k = k+1)
						for(int l=0;l<2;l = l +1) begin
							Int#(10) pixl = truncate(((i*2 + k) * (j*2 +l)) + 10)%255;
							bundle[k*2 + l] = fromInt(pixl);
						end
					wb[i*3 + j] = pack(bundle);
				end
			cnnR.windowBuffer(wb);					
					
		endrule

		rule layerOut;
				let x <- cnnR.result;
				Vector#(16, DataType) d = unpack(x);
				for(int i=0 ;i<4; i = i + 1) begin
					for(int j=0; j<4; j = j + 1)
						$display(" %d ", fxptGetInt(d[i*4 +j]));
					$display();
				end

				$finish(0);
		endrule
		

endmodule
endpackage
