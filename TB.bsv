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
import out::*;

import "BDPI" function Action initialize_image();
import "BDPI" function UInt#(32) readPixel1(UInt#(32) ri, UInt#(32) cj, UInt#(32) ch);
import "BDPI" function UInt#(32) readPixel2(UInt#(32) ri, UInt#(32) cj, UInt#(32) ch);

#define IMG 20
#define K 1


interface Std;
	method ActionValue#(Vector#(16,Bit#(16))) receive;
	method Action sliceIn(Vector#(K,Int#(10)) datas);
endinterface


(*synthesize*)
module mkTB(Std);

		Reg#(int) clk <- mkReg(0);
		Reg#(int) rows  <- mkReg(0);
       		Reg#(int) cols  <- mkReg(0);
		Reg#(Bool) init <- mkReg(True);
		Reg#(Bool) init2 <- mkReg(True);
		Reg#(UInt#(16)) c0 <- mkReg(0);
		Convolver cnnR <- mkStage;
		Store outBRAM <- mkStore;
		Pulse p1 <- mkPulse;
		Pulse p2 <- mkPulse;
		Pulse p3 <- mkPulse;
		Reg#(Int#(10)) data <- mkReg(0);
		FIFO#(Bit#(16)) forward[4][4];

		for(int i=0;i<4; i = i+1)
			for(int j=0; j<4; j = j + 1)
				forward[i][j] <- mkFIFO;


		rule init_rule (init) ;
                	init <= False;
      		endrule

		rule update_clock;
               
			clk <= clk + 1;
      		endrule
		

		rule layerIn(clk>=1);
			if(cols + 2 == IMG) begin
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
	

		rule writeMem; //( c0 < 50);
			$display(" pushing data at clock %d ", clk);
			Vector#(2, Bit#(128)) d <- cnnR.receive;
			Vector#(1, Bit#(128)) z = newVector;
			z[0] = d[0];
			outBRAM.write(z, True);
			p1.send;
			c0 <= c0 + 1;
		endrule	

		/*rule _read;
			p1.ishigh;
			Bit#(65) val1 = 12345;
			val1[64]=1;
			Bit#(64) val = val1[63:0];
			$display("%d", val);
			outBRAM.read;
			p2.send;
		endrule

		rule _latch;
			p2.ishigh;
			outBRAM.latchData;
			p3.send;
		endrule*/
	
		/*rule layerOut;
				p3.ishigh;
				c0 <= c0 + 1;
				if(c0 < 2) begin
				Vector#(K, Bit#(128)) d = outBRAM.get;
				for(int o=0; o<1; o = o + 1) begin
					Vector#(16, DataType) x = unpack(d[o]);
					for(int i=0; i<4; i = i+1)
						for(int j=0; j<4; j = j + 1)
							//forward[i][j].enq(pack(x[i*4 + j]));
							$display(" %d ", fxptGetInt(x[i*4 + j]));
				$display(" ###################### ");
				end
				$display(" -------------------------------- ");
				end
				else
				$finish(0);
		endrule*/


		rule _out;
				Vector#(2,Bit#(64)) d <- outBRAM.flushtoDRAM(100);
				$display(" flushing from memory at clk %d ", clk);
				for(int l = 0; l<K; l = l + 1) begin
					Vector#(4, DataType) data = unpack(d[l]);
                                	for(UInt#(10) i=0; i<4; i = i+1)begin
                                        	$display(" %d ", fxptGetInt(data[i]));
                                	end
					$display(" #################################### ");
				end
				$display(" ---------------------------------------- ");
				
				if(d[1] == 1)
					$finish(0);

		endrule		   

		/*rule _out2;
				let f <- outBRAM.flusherReady;
                            	if(f == 1)
					$finish(0);
		endrule*/


		method ActionValue#(Vector#(16,Bit#(16))) receive;
                        Vector#(16,Bit#(16)) datas = newVector;
                        for(UInt#(10) k=0; k<4; k = k+1)
                                for(UInt#(10) i=0; i<4; i = i+1)begin
                                        let d = forward[k][i].first;
                                        datas[4*k + i ] = d;
                                        forward[k][i].deq;
                                end
                        return datas;
                endmethod

                method Action sliceIn(Vector#(K,Int#(10)) datas);
                        data <= datas[0];
                endmethod
  
endmodule
endpackage
