package TestBench;
import DAG::*;
import TubeHeader::*;
import FixedPoint::*;
import datatypes::*;
import pulse::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;


#define K 2
#define Filters 16

#define DRAM 4
#define DW 8
#define SL 25088

interface Sort_IFC;
   method Action  put (PCIE_PKT x);
   method ActionValue #(PCIE_PKT)  get;
endinterface

(*synthesize*)
module mkTestBench(Sort_IFC);

		//##################################################### Structures ################################
                Reg#(PCIE_PKT) rg_raw_input_data <- mkRegU;
                Reg#(int) clk <- mkReg(0);
                Reg#(int) fill <- mkReg(0);
                Pulse _start <- mkPulse;
                Pulse _p <- mkPulse;
                Reg#(Int#(10)) filter <- mkReg(0);
                Reg#(Int#(10)) _ffilter <- mkReg(0);
                Reg#(Int#(12)) _LN <- mkReg(0);
                Reg#(Int#(12)) _fLN <- mkReg(0);
                Reg#(Int#(8)) layer <- mkReg(0);
                Reg#(Int#(8)) _flayer <- mkReg(0);
                Reg#(Bool) init <- mkReg(False);
                Reg#(Int#(20)) c1 <- mkReg(0);
                Reg#(Int#(20)) c2 <- mkReg(0);
                Reg#(Bool) depthDone <- mkReg(True);
                Reg#(Int#(8)) cf     <- mkReg(0);
                Reg#(Bool) c <- mkReg(False);
                Reg#(Bool) b <- mkReg(False);
                Reg#(Bool) imgFetch <- mkReg(False);
                Reg#(Bool) pad <- mkReg(False);
                Reg#(Int#(10)) filterN <- mkReg(0);
                Std cnn <- mkDAG;
                //####################################################################################################


		FIFOF#(Bit#(16)) forward[DW];
                for(int i=0 ;i< DW; i = i + 1)
                        forward[i] <- mkFIFOF;


		//###################LAYERS CODE-GEN PART ##################################
                Int#(12)  _LayerDepths[4] = {8,32,16,16};
                Int#(10)  _LayerFilters[4] ={32,16,16,16};
                Bool      _LayerMaxPool[4] = {False,False, False, False};
                //Int#(32)  _Layerimg[4]  = {16,16,112,112};
                Int#(32)  _Layerimg[4]  = {224,224,224,224};
                //Int#(20)  _LayerOutputs[4]  = {98,98,6050,6050};
                Int#(20)  _LayerOutputs[4]  = {24642,24642,24642,24642};
		//#############################################################	

		

		FIFOF#(Bit#(64)) _weight <- mkFIFOF; 
		FIFOF#(Bit#(128)) pixels <- mkFIFOF;

		rule update_clock (depthDone == False);
			clk <= clk + 1;
      		endrule


		/*rule sourceRouter;
                        _p.ishigh;
                        Vector#(2, Bit#(64)) raw_data = unpack(rg_raw_input_data.data);
                        if(rg_raw_input_data.data[1] == 1)
                                _weight.enq(raw_data[1]);
                        else begin
                                pixels.enq(rg_raw_input_data.data);
                                c2 <= c2 + 1;
                        end
                endrule*/


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
 
		rule layerIn(clk>=1 && depthDone == False && c2 < SL && pad == False); 
		
                        Vector#(K, Bit#(64)) s = unpack(pixels.first); pixels.deq; //newVector;
                                cnn.sliceIn(s);
                     
			if(c2 == SL -1 ) begin
				$display(" PADDING NOW ");
				pad <= True;
			end

		endrule

		rule padFill (pad == True);
				Vector#(K, Bit#(64)) s = newVector;
				s[0] = 0;
				s[1] = 0;
				cnn.sliceIn(s);
		endrule


		rule updateLayer (depthDone == True && b == False && c == False && imgFetch == True);
				b <= True;
				$display(" Filter %d to %d ", filter, filter + Filters);	
				if(_fLN + 4 >= _LayerDepths[_flayer]) begin
					if(_ffilter + Filters == _LayerFilters[_flayer]) begin
						_ffilter <= 0;
						_flayer <= _flayer + 1;
					end
					else
					_ffilter <= _ffilter + Filters;
					_fLN <= 0;				
				end
				else
					_fLN <= _fLN + 4;
			

				if(filter == 16)
					cnn.print;	
				
				if(_LN >= _LayerDepths[layer]) begin
					if(filter + Filters == _LayerFilters[layer]) begin
						cnn.resetNet(0 , _LayerMaxPool[layer+1], truncate(layer+1), truncate(_Layerimg[layer+1]), _LayerOutputs[layer+1]);
						filter <= 0;
						layer <= layer + 1;
					end
					else begin
						cnn.resetNet(0 , _LayerMaxPool[layer], truncate(layer), truncate(_Layerimg[layer]), _LayerOutputs[layer]);
                                        	filter <= filter + Filters;
					end
					_LN <= 4;
                                end
				else begin
                                	cnn.resetNet(truncate(_LN) , _LayerMaxPool[layer], truncate(layer), truncate(_Layerimg[layer]), _LayerOutputs[layer]);
                                	_LN <= _LN + 4;
				end

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
			$display (" waiting here %d ", clk);
			if (d) begin
				if(layer == 4)
					$finish(0);
				else
                                	depthDone <= False;
					c <= False;
                        end

		endrule

		rule update(depthDone == False);
				if(c1 <= extend( _LayerOutputs[layer])) begin
					cnn.probe;
					c1 <= c1 + 1;
				end
				else begin
				$display(" FULL DEPTH RETREIVED ");
				pad <= False;
				c2 <= 0;
				pixels.clear;
				depthDone <= True;
				end
		endrule
		

		rule collectOutput;
				Vector#(DW,Bit#(16)) data <- cnn.receive;
				for(int i=0 ;i< DW; i = i+1) begin
					DataType dx = unpack(data[i]);
					if(dx < 0)
						forward[i].enq(0);
					else
						forward[i].enq(data[i]);
				end
		endrule


		 /*method Action put (PCIE_PKT pa) if(forward[0].notFull && c2 < 128);
                        let pcie_pkt = pa;
                        rg_raw_input_data <= pa;
                        _p.send;
                 endmethod*/

	
		method Action put (PCIE_PKT pa) if(c2 < SL);
                        let pcie_pkt = pa;
                        rg_raw_input_data <= pa;
                        Vector#(2, Bit#(64)) raw_data = unpack(pcie_pkt.data);
			if(raw_data[1] == 1125912791875585) 
				_weight.enq(raw_data[0]);
			else begin
				pixels.enq(pcie_pkt.data);
                                c2 <= c2 + 1;
			end
                endmethod

                method ActionValue#(PCIE_PKT) get ();
                        Vector#(DW, Bit#(16)) d = newVector;
                        for(int i=0 ;i< DW; i = i + 1) begin
                                        d[i] = forward[i].first; forward[i].deq;
                        end

			PCIE_PKT outData = rg_raw_input_data;
                        outData.data = pack(d);
                        return outData;
                endmethod


endmodule

endpackage

