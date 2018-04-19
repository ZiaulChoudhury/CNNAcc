package TB;
import Stage::*;
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

#define IMG 16

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
			if(cols == IMG - 1) begin
                                cols <= 0;
                                rows <= rows + 2;
                        end
                        else
                        cols <= cols + 1;

			Vector#(2, DataType) s1 = newVector;
			if(rows <= IMG-2) begin
							
					Int#(10) pixl1 = truncate(((rows * cols) + 10 ) % 255);
					Int#(10) pixl2 = truncate((((rows+1) * cols) + 10 ) % 255);
					s1[0] = fromInt(pixl1);
					s1[1] = fromInt(pixl2);
					cnnR.send(s1);
			end	
			else begin
				s1[0] = 0;
				s1[1] = 0;
				cnnR.send(s1);	
			end
		endrule
		

		rule layerOut;
				if(c0 < (IMG/2-1)*(IMG-2)) begin
					Vector#(16, DataType) data <- cnnR.receive;
					$display(" %d " , fxptGetInt(data[0]));
					$display(" %d " , fxptGetInt(data[1]));
					c0 <= c0 + 1;
				end
				else begin
					$finish(0);
				end
		endrule          
endmodule
endpackage
