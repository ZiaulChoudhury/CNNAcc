package Xilibus;
import FIFO::*;
import Vector::*;
import TestBench::*;
import datatypes::*;
import FixedPoint::*;
import TubeHeader::*;

import "BDPI" function Action storePixel(Bit#(16) data1, Bit#(16) data2, Bit#(16) data3, Bit#(16) data4, Bit#(16) data5, Bit#(16) data6, Bit#(16) data7, Bit#(16) data8, Int#(32) ch, Int#(32) layer, Int#(32) img,Int#(32) pool);

import "BDPI" function Bit#(16) readPixel(Int#(32) ri, Int#(32) cj, Int#(32) ch, Int#(32) layer);
import "BDPI" function Bit#(16) readPixel1(Int#(32) ri, Int#(32) cj, Int#(32) ch, Int#(32) layer);
import "BDPI" function Action printVolume();
import "BDPI" function Action initialize_image();
import "BDPI" function Action inc();
import "BDPI" function Bit#(16) getValue(Int#(32) l, Int#(32) s, Int#(32) f, Int#(32) i);
import "BDPI" function Int#(32) checkSign(Int#(32) l, Int#(32) s, Int#(32) f, Int#(32) i);

import "BDPI" function Bit#(16) streamData1(Int#(32) index);

#define Filters 16 
#define DRAM 4
#define K 2

#define IMG 224

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
                	init <= False;	
      		endrule


		rule _CLK ;
		clk <= clk + 1;
		t <= t + 1;
		test <= test + 1;
		endrule

		//###################LAYERS CODE-GEN PART ##################################
                Int#(12)  _LayerDepths[4] = {8,32,16,16};
                Int#(10)  _LayerFilters[4] ={32,16,16,16};
                Bool      _LayerMaxPool[4] = {False,False, False, False};
                Int#(32)  _Layerimg[4]  = {224,224,224,224};
                Int#(20)  _LayerOutputs[4]  = {24642,24642,24642,24642};
                Int#(32)  _LayerInputs[4]  = {100928,201856,24642,24642};
                //#############################################################

		(*descending_urgency = "layerOut, check" *)
		rule check(clk >= 1 && stream == True);
			
			Vector#(8, Bit#(16)) s1 = newVector;
			for(int i=0 ;i<8 ; i = i + 1) begin
				Bit#(16) px = streamData1(i);
				s1[i] = px;
			end
			
			PCIE_PKT packet = PCIE_PKT {valid: 1, data: pack (s1), slot: 'h1234, pad: 'h5, last: 0};

			/*Bit#(128) load = pack(s1);
			Vector#(2, Bit#(64)) mx = unpack(load);
			$display(" %d ", mx[1]);*/
			
                        cnn.put(packet);
			inc();
			if( z >= _LayerInputs[l]-1) begin
				stream <= False;
				z <= 0;
			end
			else
				z <= z + 1;
		endrule

		rule layerOut;
				if(numFilters < Filters) begin
                                if(c0 < ((_Layerimg[l]-2)/(K))*(_Layerimg[l]-2)-1) begin
					
                                        Vector#(8, Bit#(16)) datas = newVector;
                                        PCIE_PKT dat <- cnn.get;
                                        datas = unpack(dat.data);
					DataType dx = unpack(datas[0]);
					DataType dy = unpack(datas[1]);
					if(x == 16 || l == 1)
					$display(" %d %d --- %d Layer %d ", fxptGetInt(dx), fxptGetInt(dy), c0, l);
					storePixel(datas[0], datas[1], datas[2], datas[3], datas[4], datas[5], datas[6], datas[7],numFilters, l+1, IMG,0);	
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
