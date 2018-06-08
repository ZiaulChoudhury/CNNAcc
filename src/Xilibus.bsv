package Xilibus;
import FIFO::*;
import Vector::*;
import TestBench::*;
import datatypes::*;
import FixedPoint::*;

import "BDPI" function Action storePixel(Bit#(16) data1, Bit#(16) data2, Bit#(16) data3, Bit#(16) data4, Bit#(16) data5, Bit#(16) data6, Bit#(16) data7, Bit#(16) data8, Int#(32) ch, Int#(32) layer, Int#(32) img,Int#(32) pool);

import "BDPI" function Bit#(16) readPixel(Int#(32) ri, Int#(32) cj, Int#(32) ch, Int#(32) layer);
import "BDPI" function Bit#(16) readPixel1(Int#(32) ri, Int#(32) cj, Int#(32) ch, Int#(32) layer);
import "BDPI" function Action printVolume();
import "BDPI" function Action initialize_image();
import "BDPI" function Action inc();
import "BDPI" function Bit#(16) getValue(Int#(32) l, Int#(32) s, Int#(32) f, Int#(32) i);
import "BDPI" function Int#(32) checkSign(Int#(32) l, Int#(32) s, Int#(32) f, Int#(32) i);
import "BDPI" function Bit#(16) streamData(Int#(32) index);

#define Filters 24 
#define DRAM 4
#define K 2

module mkXilibus();
       
		Sort_IFC cnn <- mkTestBench;
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
		Reg#(int) fil	    <- mkReg(0);	
		Reg#(int) c1 <- mkReg(0);
		Reg#(int) z <- mkReg(0);
		Reg#(int) l <- mkReg(0);


		rule init_rule (init);
			initialize_image();
			//cnn.start;
                	init <= False;	
      		endrule


		rule _CLK ;
		clk <= clk + 1;
		t <= t + 1;
		test <= test + 1;
		endrule


		//###################LAYERS CODE-GEN PART ##################################
                Int#(12)  _LayerDepths[4] = {8,24,24,24};
                Int#(10)  _LayerFilters[4] ={24,24,24,24};
                Bool      _LayerMaxPool[4] = {False,False, False, False};
                Int#(32)  _Layerimg[4]  = {16,16,112,112};
                //Int#(32)  _Layerimg[4]  = {224,224,224,224};
                Int#(20)  _LayerOutputs[4]  = {98,98,6050,6050};
                //Int#(20)  _LayerOutputs[4]  = {24642,24642,24642,24642};
                //#############################################################

		rule check(clk >= 1);
			
			Vector#(8, Bit#(16)) s1 = newVector;
			for(int i=0 ;i<8 ; i = i + 1) begin
				Bit#(16) px = streamData(i);
				px = ( px << 6 ) & 65472;
				s1[i] = px;
			end
			
			PCIE_PKT packet = PCIE_PKT {valid: 1, data: pack (s1), slot: 'h1234, pad: 'h5, last: 0};
                        cnn.put(packet);
			inc();
		endrule

		/*rule sendfilter (clk >=1);
				if(cf == 8) begin
					if(filterN == Filters - 1)begin
						if(_fLN >= extend(_LayerDepths[_flayer]-4)) begin
                                        		if(_ffilter + Filters == extend(_LayerFilters[_flayer])) begin
                                                		_ffilter <= 0;
                                                		_flayer <= _flayer + 1;
                                        		end
                                        		else
                                        			_ffilter <= _ffilter + Filters;
                                        	_fLN <= 0;
                                		end
                                		else
                                        	_fLN <= _fLN + 4;
						filterN <= 0;
					end
					else
                                	filterN <= filterN + 1;
                                	cf <= 0;
                                end
                                else
                                	cf <= cf + 1;
		
				Vector#(4, CoeffType) data = newVector; 
 	
				for(int i=0 ; i<4; i = i + 1) begin
					Bit#(16) val =  getValue (_flayer, _fLN+i, _ffilter + filterN, cf);
                                	Int#(32) sign = checkSign(_flayer, _fLN+i, _ffilter + filterN, cf);
                                	CoeffType x = unpack(val);
                                	CoeffType zero = 0;
                                	CoeffType xr = 0;
                                	if(sign == 1)
                                                xr = fxptTruncate(fxptSub(zero,x));
                                	else
                                                xr = x;
					data[i] = xr;
				end

                               cnn.pushFilter(pack(data));  

		endrule

		rule sendPixel (clk >= 1 && stream == True) ;
			Vector#(K, Bit#(64)) s = newVector;

			if( _LN + 4 <= extend(_LayerDepths[l])) begin
			cols <= (cols+1)%_Layerimg[layer];
                        if(cols == _Layerimg[layer]- 1) begin
					if(rows + K > 15) begin
						if(l == 1)
							rows <= 0;
						_LN <= _LN + 4;
					end
					else
						rows <= rows + K;
			end

                       						Vector#(4, DataType) m = newVector;
                       						Vector#(4, DataType) m1 = newVector;

                     
                                                               	Bit#(16) px = readPixel((rows), cols, 0, l);
								px = ( px << 6 ) & 65472;	
								
								Bit#(16) px1 = readPixel1((rows+1), cols, 0, l);
                                                                px1 = ( px1 << 6 ) & 65472;

								DataType dx  = unpack( px );
								DataType dx1 = unpack( px1 );
							
								//if(l == 1 && _LN == 4)
								//	$display(" Layer seding %d %d at @clk %d row %d col %d  ", fxptGetInt(dx), fxptGetInt(dx1), clk, rows, cols);
                                                                
								m[0] = dx;
								m1[0] = dx1; 


								px = readPixel((rows), cols, 1, l);
                                                                px = ( px << 6 ) & 65472;

                                                                px1 = readPixel1((rows+1), cols, 1, l);
                                                                px1 = ( px1 << 6 ) & 65472;

                                                                dx  = unpack( px );
                                                                dx1 = unpack( px1 );

								
								$display(" ############### ");
                                                                m[1] = dx;
                                                                m1[1] = dx1;

								px = readPixel((rows), cols, 2, l);
                                                                px = ( px << 6 ) & 65472;

                                                                px1 = readPixel1((rows+1), cols, 2, l);
                                                                px1 = ( px1 << 6 ) & 65472;

                                                                dx  = unpack( px );
                                                                dx1 = unpack( px1 );
                                                                m[2] = dx;
                                                                m1[2] = dx1;


								px = readPixel((rows), cols, 3, l);
                                                                px = ( px << 6 ) & 65472;

                                                                px1 = readPixel1((rows+1), cols, 3, l);
                                                                px1 = ( px1 << 6 ) & 65472;

                                                                dx  = unpack( px );
                                                                dx1 = unpack( px1 );
                                                                m[3] = dx;
                                                                m1[3] = dx1;
                                                		
						
                                        s[0] = pack(m);            
                                        s[1] = pack(m1);            
					cnn.pushPixels(pack(s));
			end
			else begin
					stream <= False;
			end
		
               
		endrule*/

		rule layerOut;
				if(numFilters < Filters) begin
                                if(c0 < ((_Layerimg[l]-2)/(K))*(_Layerimg[l]-2)-1) begin
					
                                        Vector#(8, Bit#(16)) datas = newVector;
                                        PCIE_PKT dat <- cnn.get;
                                        datas = unpack(dat.data);
					DataType dx = unpack(datas[0]);
					DataType dy = unpack(datas[1]);

					$display(" %d %d --- %d Layer %d ", fxptGetInt(dx), fxptGetInt(dy), c0, l);
					storePixel(datas[0], datas[1], datas[2], datas[3], datas[4], datas[5], datas[6], datas[7],numFilters, l+1, 16,0);	
					c0 <= c0 + 1;	
				end
				else begin
					c0 <= 0;
					$display(" One set done ");
					numFilters <= numFilters + DRAM;
				end
				end
				else begin
					if(x + Filters == extend(_LayerFilters[l])) begin
                                                        x <= 0;
                                                        l <= l + 1;
							rows <= 0;
							cols <= 0;
							fil <= 0;
							$display(" layer done ");
							_LN <= 0;
							stream <= True;
							printVolume();
							if(l == 1)
								$finish(0);
                                        end
                                        else
                                        x <= x + Filters;
                                        numFilters <= 0;
                                        c0 <= 0;

				end
                endrule
endmodule
endpackage
