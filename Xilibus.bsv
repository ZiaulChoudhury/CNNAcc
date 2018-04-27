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
#define DRAM 1
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

		//###################LAYERS CODE-GEN PART ##################################
                Int#(12)  _LayerDepths[1] = {3};
                Int#(10)  _LayerFilters[1] ={8};
                Bool      _LayerMaxPool[1] = {False};
                Int#(32)  _Layerimg[1]  = {16};
                Int#(20)  _LayerOutputs[1]  = {64};

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


			
			Vector#(4, Bit#(16)) s = newVector;
			
			Int#(10) d0 = truncate((rows * cols + 10)%255);
			
			DataType _d0 = fromInt(d0);
			Bit#(16) pixl = pack(_d0);
                  	//Bit#(16) pixl = readPixel((rows) , cols, _LN, layer);
                        //pixl = (pixl << 6) & 65472;
                        s[0] = pixl;


			Int#(10) d1 = truncate((rows * (cols+1) + 10)%255);
			DataType _d1 = fromInt(d1);
                        Bit#(16) pixl1 = pack(_d1);
			//Bit#(16) pixl1 = readPixel((rows) , cols+1, _LN, layer);
                        //pixl1 = (pixl1 << 6) & 65472;
                        s[1] = pixl1;

			Int#(10) d2 = truncate(((rows + 1) * cols + 10)%255);
			DataType _d2 = fromInt(d2);
                        Bit#(16) pixl2 = pack(_d2);
			//Bit#(16) pixl2 = readPixel((rows + 1) , cols, _LN, layer);
                        //pixl2 = (pixl2 << 6) & 65472;
                        s[2] = pixl2;


			Int#(10) d3 = truncate(((rows+1) * (cols+1) + 10)%255);
			DataType _d3 = fromInt(d3);
                        Bit#(16) pixl3 = pack(_d3);
			//Bit#(16) pixl3 = readPixel((rows + 1) , cols + 1, _LN, layer);
                        //pixl3 = (pixl3 << 6) & 65472;
                        s[3] = pixl3;


			Bit#(64) pixs = pack(s);
                        cnn.pushPixels(pixs);
				
				

		endrule


		rule layerOut;
				Vector#(DRAM, Bit#(64)) d <- cnn.response;
				Vector#(4, DataType) s = unpack(d[0]);
				
				for(int i=0 ;i<4; i = i + 1)
					$display(" %d ", fxptGetInt(s[i]));
				
				$finish(0);
		endrule
		/*rule layerOut;
                                if(numFilters < Filters) begin
                                if(c0 < ((_Layerimg[l]-2)/(K))*(_Layerimg[l]-2)) begin
                                        Vector#(16, Bit#(16)) datas = newVector;
                                        datas <- cnn.response;
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
                endrule*/
endmodule
endpackage
