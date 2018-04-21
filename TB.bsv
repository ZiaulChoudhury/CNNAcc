package TB;
import Stage::*;
import conv36::*;
import TubeHeader::*;
import FixedPoint::*;
import datatypes::*;
import bram::*;
import pulse::*;
import Vector::*;
import Stage::*;
import FIFO::*;

import "BDPI" function Action initialize_image();
import "BDPI" function UInt#(32) readPixel1(UInt#(32) ri, UInt#(32) cj, UInt#(32) ch);
import "BDPI" function UInt#(32) readPixel2(UInt#(32) ri, UInt#(32) cj, UInt#(32) ch);

#define IMG 32
#define K 2
(*synthesize*)
module mkTB();

		Reg#(int) clk <- mkReg(0);
		Reg#(int) rows  <- mkReg(0);
       		Reg#(int) cols  <- mkReg(0);
		Reg#(Bool) init <- mkReg(True);
		Reg#(Bool) flagg <- mkReg(True);
		Reg#(UInt#(32)) c0 <- mkReg(0);
		Reg#(UInt#(32)) c1 <- mkReg(0);
		Reg#(UInt#(32)) test_reg <- mkReg(0);
		Convolver cnnR <- mkStage;
	
		rule init_rule (init) ;
                	init <= False;
      		endrule

		rule update_clock;
               
			clk <= clk + 1;
      		endrule
		

		rule layerIn(clk>=1);
			if(cols+2 == IMG) begin
                                cols <= 0;
                                rows <= rows + 2*K;
                        end
                        else
                        cols <= cols + 2;

			Vector#(K, Bit#(64)) s = newVector;
			if(rows <= IMG-2*K) begin
					for(int k = 0; k<K; k = k +1) begin
						Vector#(4,DataType) bundle = newVector;
						for(int r=0; r<2; r = r+1)
							for(int c = 0; c <2; c = c +1) begin
								Int#(10) pixl = truncate((((rows+r+2*k) * (cols+c)) + 10 ) % 255);
								//$display(" %d r %d c %d ", pixl, rows+r+2*k, cols+c);
								bundle[r*2 + c] = fromInt(pixl);
							end	
						s[k] = pack(bundle);
					end
					cnnR.send(s);		
					
			end	
			else begin
				Bit#(64) d = 0;
				for(int k = 0; k<K; k = k +1)
				s[k] = d;
				cnnR.send(s);	
			end
		endrule
		

		rule layerOut;
				c0 <= c0 + 1;
				if(c0 < 2) begin
				Vector#(2, Bit#(256)) d <- cnnR.receive;
				for(int o=0; o<2; o = o + 1) begin
					Vector#(16, DataType) x = unpack(d[o]);
					for(int i=0; i<4; i = i+1)
						for(int j=0; j<4; j = j + 1)
							$display(" %d ", fxptGetInt(x[i*4 + j]));
				$display(" ###################### ");
				end
				$display(" -------------------------------- ");
				end
				else
				$finish(0);
		endrule      
endmodule
endpackage
