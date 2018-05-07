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

#define Filters 4
#define Depth 4
#define Roof 2
#define DRAM 4

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


		rule _CLRoof ;
		clk <= clk + 1;
		t <= t + 1;
		test <= test + 1;
		endrule

		//###################LAYERS CODE-GEN PART ##################################
                Int#(12)  _LayerDepths[3] = {4,4,4};
                Int#(10)  _LayerFilters[3] ={4,4,4};
                Bool      _LayerMaxPool[3] = {False,False, False};
                //Int#(32)  _Layerimg[4]  = {224,224,112,112};
                Int#(32)  _Layerimg[3]  = {16,16,16};
                //Int#(20)  _LayerOutputs[4]  = {24642,24642,6050,6050};
                Int#(20)  _LayerOutputs[3]  = {98,98,98};
                //##############################################################

		rule sendfilter (clk >=1);
				if(cf == 8) begin
					if(filterN + 2 == Filters)begin
						if(_fLN + Depth >= extend(_LayerDepths[_flayer])) begin
                                        		if(_ffilter + Filters == extend(_LayerFilters[_flayer])) begin
                                                		_ffilter <= 0;
                                                		_flayer <= _flayer + 1;
                                        		end
                                        		else
                                        			_ffilter <= _ffilter + Filters;
                                        	_fLN <= 0;
                                		end
                                		else
                                        	_fLN <= _fLN + Depth;
						filterN <= 0;
					end
					else
                                	filterN <= filterN + 2;
                                	cf <= 0;
                                end
                                else
                                	cf <= cf + 1;
			

				Vector#(2, Bit#(64)) s = newVector;
				for(int i=0; i<2; i = i + 1) begin
				Vector#(4, Bit#(16)) d = newVector;
					for(int j=0;j<4; j = j + 1) begin
					Bit#(16) val =  getValue (_flayer, _fLN+j, _ffilter + filterN+i, cf);
                                	Int#(32) sign = checkSign(_flayer, _fLN+j, _ffilter + filterN+i, cf);
                                	CoeffType x = unpack(val);
                               	 	CoeffType zero = 0;
                                	CoeffType xr = 0.02;
                                	/*if(sign == 1)
                                                xr = fxptTruncate(fxptSub(zero,x));
                                	else
                                                xr = x;*/
					d[j] = pack(xr);
				end
				s[i] = pack(d);
				end
                               cnn.putFilter(pack(s));  

		endrule

		rule sendPixel (clk >= 1);
			if(cols == _Layerimg[layer]- 1) begin
				if(rows+Roof == _Layerimg[layer]) begin	
					if(_LN+Depth == extend(_LayerDepths[layer])) begin
						if(filter + Filters == extend(_LayerFilters[layer])) begin
							filter <= 0;
						        layer <= layer + 1;
						end
						else
							filter <= filter + Filters; 
						_LN <= 0;
					end
					else
						_LN <= _LN + Depth;
					rows <= 0;	
				end
				else
                                rows <= rows + Roof;
                                cols <= 0;
                        end
                        else
                                cols <= cols + 1;


		
			Vector#(Roof, Bit#(64)) s = newVector;
			for(int i=0 ;i<Roof; i = i + 1) begin	
			Vector#(4, Bit#(16)) d = newVector;
				for(int j=0; j<4; j = j + 1) begin
                  			//Bit#(16) pixl = pack(truncate(((rows+i) *cols + 10))%255); //readPixel((rows+i) , cols, _LN+j, layer);
                  			Int#(10) pixl = (truncate(((rows+i) *cols + 10))%255); //readPixel((rows+i) , cols, _LN+j, layer);
                        		//pixl = (pixl << 6) & 65472;
					DataType dx = fromInt(pixl);
                        		d[j] = pack(dx);
				end
				s[i] = pack(d);
			end
                        cnn.putPixels(pack(s));
				
				

		endrule

		rule layerOut;
                                if(numFilters < Filters) begin
                                if(c0 < ((_Layerimg[l]-2)/(Roof))*(_Layerimg[l]-2)) begin
                                        Vector#(8, Bit#(16)) datas = newVector;
                                        let d  <- cnn.get;
					datas = unpack(d);
					if(_LayerMaxPool[l]) begin
						if(c0 < ((_Layerimg[l]-2)/(Roof))*(_Layerimg[l]/2-1))	
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
