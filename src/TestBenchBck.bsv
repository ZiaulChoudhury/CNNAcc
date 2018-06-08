package TestBench;
import BRam::*;
import DAG::*;
import TubeHeader::*;
import FixedPoint::*;
import datatypes::*;
import bram::*;
import pulse::*;
import Vector::*;
import Stage::*;
import FIFO::*;

import "BDPI" function Action initialize_image();
import "BDPI" function Bit#(16) readPixel(Int#(32) ri, Int#(32) cj, Int#(32) ch, Int#(32) layer);
import "BDPI" function Bit#(16) getValue(Int#(32) l, Int#(32) s, Int#(32) f, Int#(32) i);
import "BDPI" function Int#(32) checkSign(Int#(32) l, Int#(32) s, Int#(32) f, Int#(32) i);
import "BDPI" function Action storePixel(Bit#(16) data, Int#(32) ri, Int#(32) cj, Int#(32) ch, Int#(32) layer, Int#(32) img, Int#(32) pad);

#define BANKS 16
#define K 12
#define PE 8

module mkTestBench();

		Reg#(int) clk <- mkReg(0);
		Reg#(int) rows  <- mkReg(0);
       		Reg#(int) cols  <- mkReg(-1);
		Reg#(Bool) init <- mkReg(True);
		Reg#(Int#(10)) filter <- mkReg(0);
		Reg#(int) c0 <- mkReg(0);
		Reg#(int) c <- mkReg(0);
		Reg#(Bool) sliceDone <- mkReg(False);
		Reg#(Int#(12)) depth <- mkReg(0);
		Reg#(Int#(5)) layer <- mkReg(0);	
		Reg#(int) c1 <- mkReg(0);
		Reg#(int) col1 <- mkReg(0);
		Reg#(Int#(64)) wall <- mkReg(0);
		Reg#(Bool) pool <- mkReg(False);
		Reg#(Bool) clearBuf <- mkReg(False);

		//################### LAYERS ##################################
		Int#(12)  _LayerDepths[5] = {3,64,64,128,128};
		Int#(10)  _LayerFilters[5] = {64,64,128,128,16};
		Bool 	  _LayerStat[5] = {True,False,False,False,False};
		Int#(32)  _Layerimg[5]	= {224,224,112,112,112};
		Int#(12)  _LayerCores[5] = {3,PE,PE,PE,PE};
		//#############################################################
		
		Reg#(Bool) b <- mkReg(False);
		Std cnn <- mkDAG;
		Reg#(Bool) filterIn <- mkReg(False);
		Reg#(Int#(8)) cf   <- mkReg(0);
		Reg#(Bool) imgFetch <- mkReg(False);
		Reg#(Bool) chk <- mkReg(False);
		
		rule init_rule (init) ;
                	initialize_image();
                	init <= False;
      		endrule

		rule _Wall (init == False);
			wall <= wall + 1;
			//$display(" @clk %d layer %d filter %d", wall, layer ,filter);
		endrule
		rule update_clock (sliceDone == False && imgFetch == True);
                        cols <= (cols+1)%_Layerimg[layer];
                        if(cols == _Layerimg[layer] - 1)
				rows <= rows + K;
			clk <= clk + 1;
      		endrule
		

		rule filterFetch (imgFetch == False && sliceDone == False && filterIn == False);
			
				Vector#(K, Bit#(16)) s[PE];
				for(int i=0; i< PE; i = i + 1)
					s[i] = newVector;

				if (cf + 3 == 9)
					filterIn <= True;
				else
					cf <= cf + 3;

				
				
				int index = 0;
				if(cf == 0)
					index = 0;
				if(cf == 3)
					index = 3;
				if(cf == 6)
					index = 6;
				Int#(32) slice = extend(unpack(pack(depth)));
				Int#(32) filterN = extend(unpack(pack(filter)));
		
			
				if(layer == 0) begin
				for(int k=0; k< 3 ; k = k+1)
				for(int i=0; i<3; i = i+1) begin
					Bit#(16) val =  getValue (0,slice + k,filterN, index + i);
					Int#(32) sign = checkSign(0,slice + k,filterN, index + i);
					CoeffType x = unpack(val);
					CoeffType zero = 0;
					CoeffType xr = 0;
					if(sign == 1)
					xr = fxptTruncate(fxptSub(zero,x));
					else
					xr = x;
					s[k][i] = pack(xr);
				end
				cnn.fetch1(s[0],False);
				cnn.fetch2(s[1],False);
				cnn.fetch3(s[2],False);
				end
				else begin
					for(int k=0; k< PE ; k = k+1)
					for(int i=0; i<3; i = i+1) begin
					Bit#(16) val =  getValue (extend(layer),slice + k,filterN, index + i);
					Int#(32) sign = checkSign(extend(layer),slice + k,filterN, index + i);
					CoeffType x = unpack(val);
					CoeffType zero = 0;
					CoeffType xr = 0;
					if(sign == 1)
					xr = fxptTruncate(fxptSub(zero,x));
					else
					xr = x;
					s[k][i] = pack(xr);
					end
				cnn.fetch1(s[0],False);
				cnn.fetch2(s[1],False);
				cnn.fetch3(s[2],False);
				cnn.fetch4(s[3],False);
				cnn.fetch5(s[4],False);
				cnn.fetch6(s[5],False);
				cnn.fetch7(s[6],False);
				cnn.fetch8(s[7],False);
				end
				

		endrule
		
		rule _filterIn(imgFetch == False && sliceDone == False && filterIn == True);
				imgFetch <= True;
				cnn.filterFetch;
		endrule
		
		rule layerIn(clk>=1 && sliceDone == False && imgFetch == True && filterIn == True);
			Vector#(K, Bit#(16)) s1 = newVector;
			Vector#(K, Bit#(16)) s2 = newVector;
			Vector#(K, Bit#(16)) s3 = newVector;
			Vector#(K, Bit#(16)) s4 = newVector;
			Vector#(K, Bit#(16)) s5 = newVector;
			Vector#(K, Bit#(16)) s6 = newVector;
			Vector#(K, Bit#(16)) s7 = newVector;
			Vector#(K, Bit#(16)) s8 = newVector;
			if(rows <= _Layerimg[layer]-1) begin
				if(filter >= 1 && _LayerStat[layer] == True)
				cnn.convolve(True);
				else begin
				for(Int#(10) i=0; i<K; i = i+1) begin
					if(rows + extend(i) < _Layerimg[layer]) begin
							Bit#(16) pixl1 = readPixel((rows + extend(i)), cols, extend(depth+0), extend(layer));
                                                	Bit#(16) pixl2 = readPixel((rows + extend(i)), cols, extend(depth+1), extend(layer));
                                                        Bit#(16) pixl3 = readPixel((rows + extend(i)), cols, extend(depth+2), extend(layer));	
							s1[i] = pixl1;
							s2[i] = pixl2;
							s3[i] = pixl3;
							if(layer == 1) begin
								Bit#(16) pixl4 = readPixel((rows + extend(i)), cols, extend(depth+3), extend(layer));
								s4[i] = pixl4;	
								Bit#(16) pixl5 = readPixel((rows + extend(i)), cols, extend(depth+4), extend(layer));
                                                                s5[i] = pixl5;
								Bit#(16) pixl6 = readPixel((rows + extend(i)), cols, extend(depth+5), extend(layer));
                                                                s6[i] = pixl6;
								Bit#(16) pixl7 = readPixel((rows + extend(i)), cols, extend(depth+6), extend(layer));
                                                                s7[i] = pixl7;
								Bit#(16) pixl8 = readPixel((rows + extend(i)), cols, extend(depth+7), extend(layer));
                                                                s8[i] = pixl8;
							end
						end
				end
					cnn.fetch1(s1, True);
					cnn.fetch2(s2, True);
					cnn.fetch3(s3, True);
					if(layer == 1) begin
						cnn.fetch4(s4, True);
						cnn.fetch5(s5, True);
						cnn.fetch6(s6, True);
						cnn.fetch7(s7, True);
						cnn.fetch8(s8, True);
					end
				end
				
			end	
			else begin
				if(filter >= 1 && _LayerStat[layer] == True)
					cnn.convolve(True);	
				else begin
				for(Int#(10) i=0; i<K; i = i+1)
					s1[i] = 0;
				 cnn.fetch1(s1, True);	
				 cnn.fetch2(s1, True);				
				 cnn.fetch3(s1, True);	
				 if(layer == 1) begin
				 	cnn.fetch4(s1, True);
				 	cnn.fetch5(s1, True);
				 	cnn.fetch6(s1, True);
				 	cnn.fetch7(s1, True);
				 	cnn.fetch8(s1, True);
				end	
				end
						
			end
		endrule

		rule update (sliceDone == True && b == False);	
		
				b <= True; 	
				if(layer == 0) begin
					if(filter == _LayerFilters[0]-1) begin
						layer <= layer + 1;
						cnn.resetNet(0,True,True,1,224);
						pool <= True;
						chk <= True;
						filter <= 0;
					end
					else begin
						filter <= filter + 1;			
						$display(" layer 0 filter %d done", filter);
						cnn.resetNet(0,False,True,0,224);
					end
				end

					
				if(layer == 1) begin
					if(depth + PE == _LayerDepths[1]) begin
						if(filter == _LayerFilters[1]-1) begin
							layer <= layer + 1;
                                                	cnn.resetNet(0,False,False,2,112);
							pool <= False;
							filter <= 0;
							depth <= 0;
						end	
						else begin
							filter <= filter + 1;
							$display(" layer 1 filter %d done", filter);
							depth <= 0;
							cnn.resetNet(0,True,False,1,224);
						end
					end
					else begin
					cnn.resetNet(depth+PE,True,False,1,224);
					depth <= depth + PE;
					end
					
				
				end	

				if(layer == 2) begin
					if(depth + PE == _LayerDepths[2]) begin
                                                if(filter == _LayerFilters[2]-1) begin
							layer <= layer+1;
							cnn.resetNet(0,False,False,3,112);
                                                        pool <= False;
                                                        filter <= 0;
                                                        depth <= 0;

						end
                                                else begin
                                                        filter <= filter + 1;
							$display(" layer 2 filter %d done", filter);
                                                        depth <= 0;
                                                        cnn.resetNet(0,False,False,2,112);
                                                end
                                        end
                                        else begin
                                        cnn.resetNet(depth+PE,False,False,2,112);
                                        depth <= depth + PE;
                                        end

				end

				
				if(layer == 3) begin
                                        if(depth + PE == _LayerDepths[3]) begin
                                                if(filter == _LayerFilters[3]-1) begin
                                                        layer <= layer+1;
                                                        cnn.resetNet(0,True,False,4,112);
                                                        pool <= True;
                                                        filter <= 0;
                                                        depth <= 0;

                                                end
                                                else begin
                                                        filter <= filter + 1;
                                                        $display(" layer 3 filter %d done", filter);
                                                        depth <= 0;
                                                        cnn.resetNet(0,False,False,3,112);
                                                end
                                        end
                                        else begin
                                        cnn.resetNet(depth+PE,False,False,3,112);
                                        depth <= depth + PE;
                                        end

                                end

				if(layer == 4) begin
                                        if(depth + PE == _LayerDepths[4]) begin
                                                if(filter == _LayerFilters[4]-1) begin
                                                        $display(" cycles %d ", wall);
                                                        $finish(0);

                                                end
                                                else begin
                                                        filter <= filter + 1;
                                                        //$display(" layer 2 filter %d done", filter);
                                                        depth <= 0;
                                                        cnn.resetNet(0,True,False,4,112);
                                                end
                                        end
                                        else begin
                                        cnn.resetNet(depth+PE,True,False,4,112);
                                        depth <= depth + PE;
                                        end

                                end


                                cols <= 0;
				rows <= 0;
				c0 <= 0;
				col1 <= 0;
				c <=  0;
				c1 <= 0;
				cf <= 0;
				filterIn <= False;
				imgFetch <= False;
				clk <= 1;
				clearBuf <= False;
                         
                endrule

		rule updateDone (sliceDone == True && b == True);
			if(layer == 0)
				cnn.resetDone(True);
			else if(chk == True) begin
				cnn.resetDone(True);
				chk <= False;
			end
			else
				cnn.resetDone(False);
			b <= False;
			//$display("reset done success");
			sliceDone <= False;
		endrule


		rule clearBuffer(sliceDone == False && clearBuf == False);
				let d <- cnn.receive;
				clearBuf <= True;
		endrule
		rule layerOut(sliceDone == False && clearBuf == True);
				if(pool == False) begin
				if(col1 < (_Layerimg[layer]-2) && c < (_Layerimg[layer]-2)/K) begin
					Vector#(K, Bit#(16)) datas = newVector;
					datas <- cnn.receive;
					for(int i = 0; i< K; i = i+1) begin
						DataType f = unpack(datas[i]);	
							if(fxptGetInt(f) != 5 && layer < 4)
							if(f < 0)
								storePixel(0, c0+1+i, col1+1, extend(filter), extend(layer+1), _Layerimg[layer+1], 1);
							else 
								storePixel(datas[i], c0+1+i, col1+1, extend(filter), extend(layer+1), _Layerimg[layer+1], 1);
					end
					
					if(col1 == _Layerimg[layer]-3) begin
						c0 <= c0 + K;
						col1 <= 0;
						c <= c+1;
					end
					else
						col1 <= col1 + 1;
				end
				else begin
					c1 <= c1 +1;
					if(c1 < _Layerimg[layer]-2) begin
                                        	Vector#(K, Bit#(16)) datas = newVector;
                                        	datas <- cnn.receive;
						
						if(layer < 2)
                                        	for(int i = 0 ; i< 222%K ; i = i+1) begin
							DataType f = unpack(datas[i]);
								if(fxptGetInt(f) != 5 && layer < 2)
								if(f < 0)
								storePixel(0, c0+i+1, (c1+1)%(_Layerimg[layer+1]-1), extend(filter), extend(layer+1), _Layerimg[layer+1], 1);
								else
								storePixel(datas[i], c0+i+1, (c1+1)%(_Layerimg[layer+1]-1), extend(filter), extend(layer+1), _Layerimg[layer+1], 1);
						end
						else
						for(int i = 0 ; i< 110%K ; i = i+1) begin
                                                        DataType f = unpack(datas[i]);
                                                                if(fxptGetInt(f) != 5 && layer < 4)
                                                                if(f < 0)
                                                                storePixel(0, c0+i+1, (c1+1)%(_Layerimg[layer+1]-1), extend(filter), extend(layer+1), _Layerimg[layer+1], 1);
                                                                else
                                                                storePixel(datas[i], c0+i+1, (c1+1)%(_Layerimg[layer+1]-1), extend(filter), extend(layer+1), _Layerimg[layer+1], 1);
                                                end

					end
					else begin
					sliceDone <= True;
					end
					
				end
				end
				else begin
					if(col1 < (_Layerimg[layer]/2-1) && c < (_Layerimg[layer]/2-1)/(K/2)) begin
					Vector#(K, Bit#(16)) datas = newVector;
					datas <- cnn.receive;
					for(int i = 0; i< K/2; i = i+1) begin
						DataType f = unpack(datas[i]);
							if(depth + PE == _LayerDepths[4] && layer == 4)
									$display(" %d ", fxptGetInt(f));
							
							if(fxptGetInt(f) != 5 && layer < 4)
							if(f < 0)
								storePixel(0, c0+1+i, col1+1, extend(filter), extend(layer+1), _Layerimg[layer+1], 1);
							else 
								storePixel(datas[i], c0+1+i, col1+1, extend(filter), extend(layer+1), _Layerimg[layer+1], 1);
					end
					
					if(col1 == _Layerimg[layer]/2-2) begin
						c0 <= c0 + K/2;
						col1 <= 0;
						c <= c+1;
					end
					else
						col1 <= col1 + 1;
				end
				else begin
					c1 <= c1 +1;
					if(c1 < _Layerimg[layer]/2-1) begin
                                        	Vector#(K, Bit#(16)) datas = newVector;
                                        	datas <- cnn.receive;
							if(layer < 4)
                                        		for(int i = 0 ; i< 111%(K/2); i = i+1) begin
							DataType f = unpack(datas[i]);
							if(fxptGetInt(f) != 5 && layer < 4)
								if(f < 0)
								storePixel(0, c0+i+1, (c1+1)%(_Layerimg[layer+1]-1), extend(filter), extend(layer+1), _Layerimg[layer+1], 1);
								else
								storePixel(datas[i], c0+i+1, (c1+1)%(_Layerimg[layer+1]-1), extend(filter), extend(layer+1), _Layerimg[layer+1], 1);
							end
							else
							for(int i = 0 ; i< 55%(K/2); i = i+1) begin
                                                        DataType f = unpack(datas[i]);
                                                        if( depth + PE == _LayerDepths[4] && layer == 4)
                                                                        $display(" %d ", fxptGetInt(f));
                                                        end

					end
					else begin
					sliceDone <= True;
					end
					
				end
				end


				
		endrule          
endmodule

endpackage
