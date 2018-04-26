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

#define Filters 8 
#define DRAM 8
#define K 2

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
			initialize_image();
			cnn.start;
                	init <= False;	
      		endrule


		rule _CLK ;
		clk <= clk + 1;
		t <= t + 1;
		test <= test + 1;
		endrule

		//###################LAYERS CODE-GEN PART ##################################
                Int#(12)  _LayerDepths[4] = {3,8,8,8};
                Int#(10)  _LayerFilters[4] ={8,8,8,16};
                Bool      _LayerMaxPool[4] = {False,True, False, True};
                //Int#(32)  _Layerimg[4]  = {224,224,112,112};
                Int#(32)  _Layerimg[4]  = {16,16,8,8};
                //Int#(20)  _LayerOutputs[4]  = {24642,24642,6050,6050};
                Int#(20)  _LayerOutputs[4]  = {98,98,18,18};

		//##############################################################

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
			if(cols == _Layerimg[layer]- 1) begin
				if(rows+K == _Layerimg[layer]) begin	
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
                                rows <= rows + K;
                                cols <= 0;
                        end
                        else
                                cols <= cols + 1;


			
			Vector#(K, Bit#(16)) s = newVector;
		
                  	Bit#(16) pixl = readPixel((rows) , cols, _LN, layer);
                        pixl = (pixl << 6) & 65472;
                        s[0] = pixl;

			Bit#(16) pixl1 = readPixel((rows + 1) , cols, _LN, layer);
                        pixl1 = (pixl1 << 6) & 65472;
                        s[1] = pixl1;
			Bit#(32) pixs = pack(s);
                        cnn.pushPixels(pixs);
				
				

		endrule

		rule layerOut; //(!(test > 400000 && test < 500000 ) && !(test > 600000 && test < 603000 ));
                                if(numFilters < Filters) begin
                                if(c0 < ((_Layerimg[l]-2)/(K))*(_Layerimg[l]-2)) begin
                                        Vector#(16, Bit#(16)) datas = newVector;
                                        datas <- cnn.response;
					//$display(" response received @ %d ", test);
					if(_LayerMaxPool[l]) begin
						if(c0 < ((_Layerimg[l]-2)/(K))*(_Layerimg[l]/2-1))	
						for(int f = 0; f < DRAM ; f = f +1) begin
							DataType v0 = unpack(datas[f*2 + 0]);
							if(v0 < 0)
								storePixel(0, outRow, outCol, numFilters + x + f, l + 1, _Layerimg[l]/2, 1); 
							else
								storePixel(datas[f*2+0], outRow, outCol, numFilters + x + f, l + 1, _Layerimg[l]/2, 1); 

						end
						if(outCol == _Layerimg[l]/2-2) begin
							outRow <= outRow + 1;
							outCol <= 0;
						end
						else
							outCol <= outCol + 1;
					end
					else begin
						for(int f = 0; f < DRAM ; f = f +1) begin
                                                        DataType v0 = unpack(datas[f*2 + 0]);
                                                        DataType v1 = unpack(datas[f*2 + 1]);
					
							
                                                        if(v0 < 0)
                                                                storePixel(0, outRow, outCol, numFilters + x + f, l + 1, _Layerimg[l], 1);
                                                        else
                                                                storePixel(datas[f*2+0], outRow, outCol, numFilters + x  + f, l + 1, _Layerimg[l], 1);

                                                	if(v1 < 0)
                                                        	storePixel(0, outRow+1, outCol, numFilters + x + f, l + 1, _Layerimg[l], 1);
                                                	else
                                                        	storePixel(datas[f*2+1], outRow+1, outCol, numFilters + x + f, l + 1, _Layerimg[l], 1);
						end
						if(outCol == _Layerimg[l]-3) begin
                                                	outRow <= outRow + 2;
                                                	outCol <= 0;
                                        	end
                                        	else
                                                	outCol <= outCol + 1;
					end
                                      	c0 <= c0 + 1;
                                end
                                else begin
                                        c0 <= 0;
					outRow <= 0;
					outCol <= 0;
                                        numFilters <= numFilters + DRAM;
                                end
                                end
                                else begin
					if(x + Filters == extend(_LayerFilters[l])) begin
							x <= 0;
							l <= l + 1;						
					end
					else
						x <= x + Filters;
                                        numFilters <= 0;
					c0 <= 0;
				end
                endrule
endmodule
endpackage
