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
import BRAMFIFO::*;
import FIFOF::*;


#define K 2
#define Filters 8
#define DRAM 8
#define DW 16

interface MIC;
	method Action pushFilter(Bit#(16) weight);
	method Action pushPixels(Bit#(32) pxls);
	method ActionValue#(Bit#(1)) sliceDone;
	method ActionValue#(Bit#(64)) sendPix;
	method ActionValue#(Vector#(DW,Bit#(16))) response;
	method Action start;
endinterface

(*synthesize*)
module mkTestBench(MIC);


		Pulse _start <- mkPulse;
		Reg#(int) clk <- mkReg(0);
		Reg#(int) rows  <- mkReg(0);
       		Reg#(int) cols  <- mkReg(0);
		Reg#(Bool) init <- mkReg(True);
		Reg#(int) filter <- mkReg(0);
		Reg#(int) layer <- mkReg(0);
		Reg#(int) l <- mkReg(0);
		
		Reg#(int) _flayer <- mkReg(0);
		Reg#(int) _ffilter <- mkReg(0);
		Reg#(int) _fLN <- mkReg(0);
			
		Reg#(int) filterN <- mkReg(0);
		Reg#(Bool) depthDone <- mkReg(True);
		Reg#(int) _LN <- mkReg(0);
		Reg#(int) c1 <- mkReg(0);
		Reg#(int) c2 <- mkReg(0);
		Reg#(int) fc <- mkReg(0);
		Reg#(int) outRow <- mkReg(0);
		Reg#(int) outCol <- mkReg(0);
		Reg#(int) c0 <- mkReg(0);	
		Reg#(int) numFilters <- mkReg(0);
		Reg#(Bool) inc <- mkReg(False);
		Reg#(Bool) b <- mkReg(False);
		Reg#(int)  wall <- mkReg(0);
		Reg#(Bool) c <- mkReg(False);
		Std cnn <- mkDAG;
		Reg#(int) cf 	    <- mkReg(0);
		Reg#(int) test 	    <- mkReg(0);
		Reg#(int) x	    <- mkReg(0);
		Reg#(Bool) imgFetch <- mkReg(False);
		FIFOF#(Bit#(16)) forward[DW];

		for(int i=0 ;i< DW; i = i + 1)
			forward[i] <- mkFIFOF;

		//###################LAYERS CODE-GEN PART ##################################
                Int#(12)  _LayerDepths[4] = {3,8,8,8};
                Int#(10)  _LayerFilters[4] ={8,8,8,16};
                Bool      _LayerMaxPool[4] = {False,True, False, True};
                //Int#(32)  _Layerimg[4]  = {224,224,112,112};
                Int#(32)  _Layerimg[4]  = {16,16,8,8};
                //Int#(20)  _LayerOutputs[4]  = {24642,24642,6050,6050};
                Int#(20)  _LayerOutputs[4]  = {98,98,18,18};
		//#############################################################	

		

		FIFOF#(Bit#(16)) _weight <- mkFIFOF; //mkSizedBRAMFIFOF(1000);
		FIFO#(Bit#(1))  stat <- mkFIFO;
		FIFOF#(Bit#(64)) pixResponse <- mkFIFOF;
		FIFOF#(Bit#(32)) pixels <- mkFIFOF; //mkSizedBRAMFIFOF(1000);

		rule init_rule (init);
			_start.ishigh;
			//$display(" DATA initialized in host " );
                	init <= False;	
      		endrule

		rule update_clock (depthDone == False);
			clk <= clk + 1;
      		endrule

		rule _CLk;
			wall <= wall + 1;
		endrule
		

		(*descending_urgency = " filterFetch, updateLayer " *)
	        rule filterFetch (filterN < Filters && init == False);
				let d = _weight.first; _weight.deq;
				cnn.filter(d, truncate(filterN), truncate(cf));	 
                                if(cf == 8) begin
                                filterN <= filterN + 1;
				cf <= 0;
				end
				else
                                cf <= cf + 1;
				if (filterN == Filters - 1 && cf == 8)
					imgFetch <= True;

                endrule
 
		rule layerIn(clk>=1 && depthDone == False); 
                        if(cols == _Layerimg[layer]- 1) begin
                                rows <= rows + K;
				cols <= 0;
			end
			else
				cols <= cols + 1;

                        Vector#(K, Bit#(16)) s = newVector;
                        if(rows <= _Layerimg[layer]-1) begin
				Vector#(K, Bit#(16)) m = unpack(pixels.first); pixels.deq;
                                for(Int#(10) i=0; i<K; i = i+1)
                                if(rows + extend(i) < _Layerimg[layer]) begin
                                                        s[i] = m[i];
                                end
                                cnn.sliceIn(s);
                        end
                        else begin
                                for(Int#(10) i=0; i<K; i = i+1)
                                        s[i] = 0;
                                cnn.sliceIn(s);
                        end

		endrule


		rule updateLayer (depthDone == True && b == False && c == False && imgFetch == True);
				b <= True;
				//stat.enq(1);
				$display(" Filter %d to %d ", filter, filter + Filters);	
				if(_fLN + 1 == extend(_LayerDepths[_flayer])) begin
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
				
				
				if(_LN == extend(_LayerDepths[layer])) begin
					if(filter + Filters == extend(_LayerFilters[layer])) begin
						cnn.resetNet(0 , _LayerMaxPool[layer+1], truncate(layer+1), truncate(_Layerimg[layer+1]), _LayerOutputs[layer+1]);
						filter <= 0;
						layer <= layer + 1;
					end
					else begin
						cnn.resetNet(0 , _LayerMaxPool[layer], truncate(layer), truncate(_Layerimg[layer]), _LayerOutputs[layer]);
                                        	filter <= filter + Filters;
					end
					_LN <= 1;
                                end
				else begin
                                	cnn.resetNet(truncate(_LN) , _LayerMaxPool[layer], truncate(layer), truncate(_Layerimg[layer]), _LayerOutputs[layer]);
                                	_LN <= _LN + 1;
				end

                                cols <= 0;
				rows <= 0;
				c1 <= 0;
				fc <= 0;
				filterN <= 0;
				clk <= 1;
                         
                endrule

		rule updateDone (depthDone == True && b == True);
			cnn.resetDone;
			b <= False;
			c <= True;
		endrule
		
		rule checkFlush(depthDone == True && c == True);
			let d = cnn.flushDone;
			if (d) begin
				if(layer == 4)
					$finish(0);
				else
                                	depthDone <= False;
					c <= False;
                        end

		endrule

		rule update(depthDone == False);
				//if(c1 < ((_Layerimg[layer]-2)/(K))*(_Layerimg[layer]-2)) begin
				if(c1 < extend(_LayerOutputs[layer])) begin
					cnn.probe;
					c1 <= c1 + 1;
				end
				else
				depthDone <= True;
		endrule
		

		rule collectOutput;
				Vector#(DW,Bit#(16)) data <- cnn.receive;
				for(int i=0 ;i< DW; i = i+1)
					forward[i].enq(data[i]);
		endrule

		method Action pushFilter(Bit#(16) weight) if(forward[0].notFull); 
				_weight.enq(weight);			
		endmethod

		
		method ActionValue#(Bit#(1)) sliceDone;
				let d = stat.first; stat.deq;
				return d;
		endmethod

		
		method ActionValue#(Bit#(64)) sendPix;
				let d = pixResponse.first; pixResponse.deq;
				return d;
		endmethod

		method ActionValue#(Vector#(DW,Bit#(16))) response;
			Vector#(DW, Bit#(16)) d = newVector;
			for(int i=0 ;i< DW; i = i + 1) begin
					d[i] = forward[i].first; forward[i].deq;
			end
		        return d;
		endmethod

		method Action start;
			_start.send;
		endmethod
		
		method Action pushPixels(Bit#(32) pxls) if(forward[0].notFull); 
				pixels.enq(pxls);				
		endmethod

endmodule

endpackage

