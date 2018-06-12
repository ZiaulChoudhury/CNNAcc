package Stage;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import pulse::*;
import FixedPoint::*;
import datatypes::*;
import TubeHeader::*;
import BRam::*;
import mul::*;
import conv36::*;


#define Filters 16
#define Roof 2
#define Stencil 3
#define Banks 4
#define DW 32

#define DEBUG 0

interface Convolver;
        method Action weights(Vector#(Filters, Vector#(9,Bit#(64))) datas);
        method Action send(Vector#(Roof,Bit#(64)) datas);
        method ActionValue#(Vector#(DW,DataType)) receive;
        method Action reboot(Int#(10) img);
        method Action rebootDone;
	method Action print;
endinterface: Convolver


(*synthesize*) 
	module mkStage(Convolver);

		
		//############################################# INITS ############################################
		Reg#(Bool) _rebut <- mkReg(False);
		Reg#(Bool) _print <- mkReg(False);
                Reg#(UInt#(4)) _FR <- mkReg(0);	
		Reg#(Bit#(64)) windowBuffer[Roof][Stencil*Stencil];
		Reg#(UInt#(10)) res[Roof];
		Reg#(Int#(32)) clk <- mkReg(0);
		Reg#(UInt#(10))  img <- mkReg(0);
		FIFOF#(Bit#(64)) instream[Banks];
		Reg#(Bit#(64)) data[Roof][Stencil];
		Reg#(Bit#(64)) store[Banks];
		FIFOF#(DataType) forward[Filters][Roof];
		Conv36 _PE[Filters][Roof];
		Reg#(Bit#(1)) _macPulse[Filters][Roof];
		Reg#(Bit#(1)) _macP[Roof]; 
		Pulse 	collPulse[Roof];
		Pulse 	_ena <- mkPulse; 
		Pulse 	_l <- mkPulse; 
		Pulse                                           _bp[Roof];
                Pulse                                           _bp0 <- mkPulse;
                Pulse                                           _bp1 <- mkPulse;
                Pulse                                           _bp2 <- mkPulse;
                Reg#(BramLength)                           	r2 <- mkReg(0);
                Reg#(BramLength)                           	r1 <- mkReg(0);
		Reg#(BramWidth) 				c2 <- mkReg(0);
		Reg#(BramWidth) 				c1 <- mkReg(0);
		Reg#(Bool)                                      fetch <- mkReg(False);
                Reg#(Bool)                               	startRead    <- mkReg(False);		
		Bram 						inputFmap    <- mkBram(Banks); 					
		Reg#(Bool)                               	_latch       <- mkReg(False);
		FIFOF#(BramLength) 				_readIndex[Roof][Stencil]; 
		//################################################################################################




		for(BramLength i=0; i <Banks; i = i +1 ) begin
			instream[i] <- mkFIFOF;
			store[i] <- mkReg(0);
		end

		for(int k = 0; k< (Roof); k = k+1) begin
			collPulse[k] <- mkPulse;
			_bp[k] <- mkPulse;
			res[k] <- mkReg(0);
			_macP[k] <- mkReg(0);
			for(int i=0;i<  (Stencil) ; i = i+1) begin
				data[k][i] <- mkReg(0);
				_readIndex[k][i] <- mkSizedFIFOF(16);
			end
		end

		for(int k = 0; k<  (Roof); k = k+1)
			for(int i= 0;i < (Stencil*Stencil); i = i+1) begin
				windowBuffer[k][i] <- mkReg(0);
			end
		
		for(int f = 0 ;f < Filters; f = f + 1)		
			for(int k = 0; k<  (Roof); k = k+1) begin
			forward[f][k] <- mkSizedFIFOF(32);
			_PE[f][k] <- mkConv36;
                        _macPulse[f][k]<- mkReg(0);
		end

		rule _CLK ;
			clk <= clk + 1;
		endrule
		
		rule _DRAMStrideFetch( /* fetch == True && */ _rebut == False);	
				if(DEBUG == 1)
					$display("conv|%d", clk);

				 if(c1 ==  extend(img-1)) begin
                                 	c1 <= 0;
                                 	if(r1 +  (Roof) >=  (Banks))
                                 		r1 <= 0;
                                 else 
                                        r1 <= r1 +  (Roof);
                                 end
                                 else
                                 c1 <= c1 + 1;
				 
				 for(BramLength i = 0; i <  (Roof); i = i +1) begin
				 	let d = instream[i].first; instream[i].deq;
					let index = (r1 + i)% (Banks);
					//Vector#(4, DataType) dat = unpack(d);
                                	//	$display(" ---> WRITES  convolution %d @clk ", fxptGetInt(dat[0]), clk);
					inputFmap.write(d, index, c1);
				 end

				 if(r1 >=  (Stencil)-1 && c1 >=  (Stencil))
				 startRead <= True;
			
				 if(startRead == True) begin
				 //$display(" START THE ENGINE ");
				 _ena.send;
				end
				_bp0.send;
		endrule

		rule _BRAMfetch (_rebut == False);
			if(DEBUG == 1)
                                        $display("conv|%d", clk);
			_ena.ishigh;
			_bp0.ishigh;

			  	if(c2 ==  extend(img-1)) begin
                                	c2 <= 0;
                          	if (r2 +  (Roof) >=  (Banks))
                                        r2 <= 0;
                                else 
                                        r2 <= r2 +  (Roof);
                          	end
                          	else
                                c2 <= c2 + 1;

			for(BramLength i = 0; i <  (Banks); i = i +1) begin
					   let index  = (r2 + i)% (Banks); 
					   //$display(" READING FROM %d @CLK %d ", c2, clk);
					   inputFmap.read(index, c2);
			end
			for(BramLength k = 0; k <  (Roof); k = k + 1)
				for(BramLength i = 0; i <  (Stencil); i = i +1) begin
					let index = (r2 + i + k)% (Banks);
					_readIndex[k][i].enq(index);
                         	end
			_bp1.send;
		endrule

		rule _latchData (_rebut == False);
                        //$display(" LATCHING DATA AT |%d", clk);
			inputFmap.latch;
			_l.send;
			_bp1.ishigh;
		endrule

		rule _storeData;
			if(DEBUG == 1)
                                        $display("conv|%d", clk);
			_l.ishigh;
                        for(BramLength i =0 ;i<Banks; i = i+1) begin
                                store[i] <= inputFmap.get(i);
				
				/*if(_print == True) begin
				Vector#(4, DataType) dat = unpack(inputFmap.get(i));
                                $display(" ---> sending for convolution %d @clk ", fxptGetInt(dat[0]), clk);
				end*/

                        end
			_latch <= True;
			for(int k = 0; k<Roof; k = k+1)
				_bp[k].send;
		endrule

		for (int k = 0 ; k < (Roof); k = k+1) begin
		rule getData (_latch== True);
				_bp[k].ishigh;
				if(DEBUG == 1 && k == 0 )
                                        $display("conv|%d", clk);

				for(Int#(8) i=0;i<  (Stencil) ; i = i+1) begin
	                                let index =  _readIndex[k][i].first; _readIndex[k][i].deq; 
					let d = store[index];
					data[k][i] <= d;
				end
				collPulse[k].send;
		endrule
		

		rule collect; 
			if(DEBUG == 1 && k == 0)
                                        $display("conv|%d", clk);
			collPulse[k].ishigh;
			for (UInt#(8) i =  (Stencil*Stencil) - 1; i >=  (Stencil); i = i-1)
				windowBuffer[k][i- (Stencil)] <= windowBuffer[k][i];
			
		
			for (UInt#(8) i = 0;i <  (Stencil); i = i+1) begin
				let d = data[k][i];
				windowBuffer[k][ (Stencil*Stencil-Stencil)+i] <= d;
			end

			if(res[k] ==  extend(img-1))
				res[k] <= 0;
			else
				res[k] <= res[k] + 1;

			if(res[k] >=  (Stencil)-1)
                                   _macP[k] <= ~_macP[k];
		endrule


		

		for(int f = 0 ; f<Filters; f = f + 1) begin
                                        rule pushMac ((_macP[k] ^ _macPulse[f][k]) == 1);
						_macPulse[f][k] <= _macP[k];
                                                Vector#(9, Bit#(64))  _WB = newVector;
					
                                                 for(int i=0; i< (Stencil*Stencil); i = i+1) begin
                                                        _WB[i] = windowBuffer[k][i];
                                                 end
						
                                     	        _PE[f][k].sendP(_WB);
                                        endrule

                                        rule popMAC (_rebut == False);
                                                let d <- _PE[f][k].result;
                                                forward[f][k].enq(d);
                                        endrule



                end
                end


		rule _reboot (_rebut == True && _FR > 0);
                        _latch <= False;
                    
			$display(" convolver cleaned @clk %d " , clk);
			_bp0.clean;	
			_bp1.clean;
                        for(int i=0; i<fromInteger(Roof); i = i+1) begin
				instream[i].clear;
				_bp[i].clean;
				_macP[i] <= 0;
                                collPulse[i].clean;
				res[i] <= 0;
			        for(int j=0;j<fromInteger(Stencil); j = j + 1)
                                         _readIndex[i][j].clear;
	
			end
			
			for(int f = 0 ; f< Filters; f = f +1)
                        for(int i=0; i<fromInteger(Roof); i = i+1) begin
                                forward[f][i].clear;
				_PE[f][i].clean;
				_macPulse[f][i] <= 0;
                        end
			
                        c1 <= 0;
                        c2 <= 0;
                        r2 <= 0;
                        r1 <= 0;
                        startRead <= False;
                        _ena.clean;
                        _l.clean;
                        _FR <= _FR - 1;
                endrule

		rule _reboot_mem(_FR == 2  && _rebut == True);
                                inputFmap.clean;
                endrule


		method Action send(Vector#(Roof,Bit#(64)) datas);
				for(int i=0; i< Roof; i = i + 1) begin
					let dat = datas[i];
					instream[i].enq(dat);	
				end
		endmethod
                
		method ActionValue#(Vector#(DW,DataType)) receive if(_rebut == False);
					Vector#(DW,DataType) datas = newVector;
					for(int f=0; f<Filters; f = f +1)
						for(int k = 0 ; k <Roof; k = k + 1)  begin
                        				let d = forward[f][k].first; forward[f][k].deq; 
							datas[f*Roof + k] = d;   
					end
			return datas;
                endmethod
		
		 method Action reboot(Int#(10) im);
                        img <= unpack(pack(im));
                        _rebut <= True;
                        _FR <= 2;
                endmethod

                method Action rebootDone if(_FR == 0);
                                _rebut <= False;
                endmethod

        	method Action weights(Vector#(Filters,Vector#(9,Bit#(64))) datas);
			for(int i=0; i<Filters ; i = i + 1) begin
				 _PE[i][0].sendF(datas[0]);
				 _PE[i][1].sendF(datas[1]);
			end

		endmethod

		method Action print;
			_print <= True;
		endmethod
	  endmodule: mkStage

endpackage: Stage
                       
