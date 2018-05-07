package TestBench;
import BRam::*;
import DAG::*;
import FixedPoint::*;
import datatypes::*;
import pulse::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;

#define Roof 2
#define Filters 4
#define Depth 4


#define DRAM 8

interface MIC;
	method Action putPixels(Bit#(128) packet);
	method Action putFilter(Bit#(128) packet);
	method ActionValue#(Bit#(128)) get;
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
		Reg#(int) _flayer <- mkReg(0);
		Reg#(int) _ffilter <- mkReg(0);
		Reg#(int) _fdepth <- mkReg(0);
		Reg#(int) filterN <- mkReg(0);
		Reg#(Bool) depthDone <- mkReg(True);
		Reg#(int) depth <- mkReg(0);
		Reg#(int) c1 <- mkReg(0);
		Reg#(int) numFilters <- mkReg(0);
		Reg#(Bool) b <- mkReg(False);
		Reg#(Bool) c <- mkReg(False);
		Std cnn <- mkDAG;
		Reg#(int) cf 	    <- mkReg(0);
		Reg#(Bool) imgFetch <- mkReg(False);
		FIFOF#(Bit#(16)) forward[DRAM];
		for(int i=0 ;i< DRAM; i = i + 1)
			forward[i] <- mkFIFOF;


		 //###################LAYERS CODE-GEN PART ##################################
                Int#(12)  _LayerDepths[3] = {4,4,4};
                Int#(10)  _LayerFilters[3] ={4,4,4};
                Bool      _LayerMaxPool[3] = {False,False,False};
                //Int#(32)  _Layerimg[4]  = {224,224,112,112};
                Int#(32)  _Layerimg[3]  = {16,16,16};
                //Int#(20)  _LayerOutputs[4]  = {24642,24642,6050,6050};
                Int#(20)  _LayerOutputs[3]  = {98,98, 98};
                //##############################################################

		FIFO#(Bit#(1))  stat <- mkFIFO;
		FIFOF#(Bit#(128)) pixels <- mkFIFOF;
		FIFOF#(Bit#(128)) filterQ <- mkFIFOF;

		rule init_rule (init);
			_start.ishigh;
                	init <= False;	
      		endrule

		rule update_clock (depthDone == False);
			clk <= clk + 1;
      		endrule

		(*descending_urgency = " filterFetch, layerIn, updateLayer " *)
	        rule filterFetch (filterN < Filters && init == False);
				let d = filterQ.first; filterQ.deq;
				cnn.filter(d, truncate(filterN), truncate(cf));
                                if(cf == 8) begin
                                	filterN <= filterN + 2; 
					cf <= 0;
				end
				else
                                	cf <= cf + 1;
				
				if (filterN + 2 == Filters && cf == 8)
					imgFetch <= True;

                endrule
 
		rule layerIn(clk>=1 && depthDone == False); 
                        if(cols == _Layerimg[layer]- 1) begin
                                rows <= rows + Roof;
				cols <= 0;
			end
			else
				cols <= cols + 1;
			
			Vector#(Roof, Bit#(64)) s = replicate(0);
                        if(rows <= _Layerimg[layer]-1) begin
				s = unpack(pixels.first);pixels.deq;
                                cnn.sliceIn(s);
                        end
                        else
                                cnn.sliceIn(s);
                
		endrule


		rule updateLayer (depthDone == True && b == False && c == False && imgFetch == True);
				b <= True;
				$display(" Filter %d to %d ", filter, filter + Filters);	
				if(_fdepth + Depth >= extend(_LayerDepths[_flayer])) begin
					if(_ffilter + Filters == extend(_LayerFilters[_flayer])) begin
						_ffilter <= 0;
						_flayer <= _flayer + 1;
					end
					else
					_ffilter <= _ffilter + Filters;
					_fdepth <= 0;				
				end
				else
					_fdepth <= _fdepth + Depth;		

				if(depth >= extend(_LayerDepths[layer])) begin
					if(filter + Filters == extend(_LayerFilters[layer])) begin
						cnn.resetNet(0 , _LayerMaxPool[layer+1], truncate(layer+1), truncate(_Layerimg[layer+1]), _LayerOutputs[layer+1]);
						filter <= 0;
						layer <= layer + 1;
					end
					else begin
						cnn.resetNet(0 , _LayerMaxPool[layer], truncate(layer), truncate(_Layerimg[layer]), _LayerOutputs[layer]);
                                        	filter <= filter + Filters;
					end
					depth <= Depth;
                                end
				else begin
                                	cnn.resetNet(truncate(depth) , _LayerMaxPool[layer], truncate(layer), truncate(_Layerimg[layer]), _LayerOutputs[layer]);
                                	depth <= depth + Depth;
				end

                                cols <= 0;
				rows <= 0;
				c1 <= 0;
				filterN <= 0;
				clk <= 1;
                endrule

		rule updateDone (depthDone == True && b == True);
			cnn.resetDone;
			b <= False;
			c <= True;
		endrule
		
		rule checkFlush(depthDone == True && c == True);
		let d <- cnn.flushDone;
			if (d) begin
				if(layer == 3)
					$finish(0);
				else
                                	depthDone <= False;
					c <= False;
                        end

		endrule

		rule update(depthDone == False);
				if(c1 < extend(_LayerOutputs[layer])) begin
					cnn.probe;
					c1 <= c1 + 1;
				end
				else begin
				depthDone <= True;
				end
		endrule
		

		rule collectOutput (depthDone == False);
				Vector#(DRAM,Bit#(16)) data <- cnn.receive;
				for(int i=0 ;i< DRAM; i = i+1)
					forward[i].enq(data[i]);
		endrule


		method ActionValue#(Bit#(128)) get;
			Vector#(DRAM, Bit#(16)) d = newVector;
			for(int i=0 ;i< DRAM; i = i + 1) begin
					d[i] = forward[i].first; forward[i].deq;
			end
		        return pack(d);
		endmethod

		method Action start;
			_start.send;
		endmethod
		
		method Action putFilter(Bit#(128) packet);
				filterQ.enq(packet);
		endmethod
		
		method Action putPixels(Bit#(128) packet) if(forward[0].notFull); 
				pixels.enq(packet);				
		endmethod

endmodule

endpackage

