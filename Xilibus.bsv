package Xilibus;
import FIFO::*;
import Vector::*;
import TestBench::*;
import datatypes::*;
import FixedPoint::*;

import "BDPI" function Action storePixel(Bit#(16) data, Int#(32) ri, Int#(32) cj, Int#(32) ch, Int#(32) layer, Int#(32) img, Int#(32) pad);
import "BDPI" function Bit#(16) readPixel(Int#(32) ri, Int#(32) cj, Int#(32) ch, Int#(32) layer);
import "BDPI" function Action initialize_image();
import "BDPI" function Bit#(16) getValue(Int#(32) l, Int#(32) s, Int#(32) f, Int#(32) i);
import "BDPI" function Int#(32) checkSign(Int#(32) l, Int#(32) s, Int#(32) f, Int#(32) i);

#define Filters 2 
#define DW 2
#define K 1

module mkXilibus();
       
		MIC cnn <- mkTestBench;
		Reg#(int) clk <- mkReg(0);
		Reg#(int) _flayer <- mkReg(0);
                Reg#(int) _ffilter <- mkReg(0);
                Reg#(int) _fLN <- mkReg(0);
		Reg#(int) filterN <- mkReg(0);
		Reg#(int) cf <- mkReg(0);
		Reg#(Int#(64)) test <- mkReg(0);
		Reg#(int) t <- mkReg(0);
		Reg#(Bool) init <- mkReg(True);


		Reg#(int) rows  <- mkReg(0);
                Reg#(int) cols  <- mkReg(0);
		Reg#(int) filter <- mkReg(0);
                Reg#(int) _LN <- mkReg(0);
		Reg#(int) layer <- mkReg(0);
		
		Reg#(Bool) stream <- mkReg(True);


		Reg#(int) outRow <- mkReg(0);
		Reg#(int) outCol <- mkReg(0);
		Reg#(int) c0 <- mkReg(0);
		Reg#(int) numFilters <- mkReg(0);
		Reg#(int) x	    <- mkReg(0);	
		Reg#(int) c1 <- mkReg(0);
		Reg#(int) l <- mkReg(0);


		rule init_rule (init);
			//initialize_image();
			cnn.start;
                	init <= False;	
      		endrule


		rule _CLK ;
		clk <= clk + 1;
		t <= t + 1;
		test <= test + 1;
		endrule

		//################### LAYERS CODE-GEN PART ##################################
                Int#(12)  _LayerDepths[1] = {1};
                Int#(10)  _LayerFilters[1] ={8};
                Bool      _LayerMaxPool[1] = {False};
                Int#(32)  _Layerimg[1]  = {224};
                Int#(20)  _LayerOutputs[1]  = {12544};
		//###########################################################################

		rule sendfilter (clk >=1);
				if(cf == 8) begin
					if(filterN == Filters - 1)begin
						if(_fLN == extend(_LayerDepths[_flayer]-1)) begin
                                        		if(_ffilter + Filters == extend(_LayerFilters[_flayer])) begin
                                                		_ffilter <= 0;
                                                		_flayer <= _flayer + 1;
                                        		end
                                        		else
                                        			_ffilter <= _ffilter + Filters;
                                        	_fLN <= 0;
                                		end
                                		else
                                        	_fLN <= _fLN + 1;
						filterN <= 0;
					end
					else
                                	filterN <= filterN + 1;
                                	cf <= 0;
                                end
                                else
                                	cf <= cf + 1;
			
				Bit#(16) val =  getValue (_flayer, _fLN, _ffilter + filterN, cf);
                                Int#(32) sign = checkSign(_flayer, _fLN, _ffilter + filterN, cf);
                                CoeffType x = unpack(val);
                                CoeffType zero = 0;
                                CoeffType xr = 0;
                                if(sign == 1)
                                                xr = fxptTruncate(fxptSub(zero,x));
                                else
                                                xr = x;

                               	cnn.pushFilter(pack(xr));  

		endrule

		rule sendPixel (clk >= 1);
			if(cols + 2 == _Layerimg[layer]) begin
				if(rows + 2*K == _Layerimg[layer]) begin	
					if(_LN == extend(_LayerDepths[layer]-1)) begin
						if(filter + Filters == extend(_LayerFilters[layer])) begin
							filter <= 0;
						        layer <= layer + 1;
						end
						else
							filter <= filter + Filters; 
						_LN <= 0;
					end
					else
						_LN <= _LN + 1;
					rows <= 0;	
				end
				else
                                rows <= rows + 2*K;
                                cols <= 0;
                        end
                        else
                                cols <= cols + 2;



			Vector#(K, Bit#(64)) s = newVector;
			for(int k = 0; k<K; k = k +1) begin
                                                Vector#(4,DataType) bundle = newVector;
                                                for(int r=0; r<2; r = r+1)
                                                        for(int c = 0; c <2; c = c +1) begin
                                                                Int#(10) pixl = truncate((((rows+r+2*k) * (cols+c)) + 10 ) % 255);
                                                                bundle[r*2 + c] = fromInt(pixl);
                                                        end
                                                s[k] = pack(bundle);
                        end

                        cnn.pushPixels(s);
				
				

		endrule


		rule layerOut;
				c0 <= c0 + 1;
				$display(" reading data at cycle  %d ", clk);
				Vector#(DW, Bit#(64)) d <- cnn.response;
				for(int i = 0; i<DW; i = i + 1) begin
					Vector#(4, DataType) s = unpack(d[i]);
					for(int p=0 ;p<4; p = p + 1)
						$display(" %d ", fxptGetInt(s[p]));
					$display(" ############################### ");
				end
				$display(" ------------------------------------");
				if(c0 == 12431) begin
					$display(" total number of cycles is %d ", clk);
					$finish(0);
				end
		endrule
endmodule
endpackage
