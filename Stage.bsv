package Stage;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import pulse::*;
import FixedPoint::*;
import datatypes::*;
import TubeHeader::*;
import reduce3::*;
import BRam::*;
import mul::*;
import pool2::*;
import conv36::*;


#define Filters 2
#define Roof 1
#define Stencil 3
#define Banks 4
#define DW 2
#define DEBUG 0

interface Convolver;
        method Action weights(Vector#(1200,CoeffType) datas);
        method Action send(Vector#(Roof,Bit#(64)) datas);
        method ActionValue#(Vector#(DW,Bit#(128))) receive;
        method Action reboot(Int#(10) img, Bool dP);
        method Action rebootDone;
endinterface: Convolver


(*synthesize*) 
	module mkStage(Convolver);

		
		//############################################# INITS ############################################
		Reg#(Bool) _rebut <- mkReg(False);
                Reg#(UInt#(8)) _FR <- mkReg(0);	
		Reg#(Bit#(64)) windowBuffer[Roof][Stencil*Stencil];
		Reg#(CoeffType) coeffs[Filters*Stencil*Stencil];
		Reg#(UInt#(10)) res[Roof];
		Reg#(Int#(32)) clk <- mkReg(0);
		Reg#(UInt#(10))  img <- mkReg(112);
		FIFOF#(Bit#(64)) instream[Banks];
		Reg#(Bit#(64)) data[Roof][Stencil];
		Reg#(Bit#(64)) store[Banks];
		FIFOF#(Bit#(128)) forward[Filters][Roof];
		Pool2 pools[Filters][Roof];
		Conv36 convs[Filters][Roof];
		Pulse _macPulse[Filters][Roof];
		Pulse 	collPulse[Roof];
		Pulse 	_ena <- mkPulse; 
		Pulse 	_l <- mkPulse; 
		Pulse                                   	_recvEnable[Filters][Roof];
		Pulse                                   	_forEnable[Filters][Roof];
		Pulse                                           _bp[Roof];
                Pulse                                           _bp0 <- mkPulse;
                Pulse                                           _bp1 <- mkPulse;
                Pulse                                           _bp2 <- mkPulse;
		Reg#(Bit#(64))                          	recvData[Filters][Roof];
                Reg#(BramLength)                           	r2 <- mkReg(0);
                Reg#(BramLength)                           	r1 <- mkReg(0);
		Reg#(BramWidth) 				c2 <- mkReg(0);
		Reg#(BramWidth) 				c1 <- mkReg(0);
		Reg#(Bool)                                      _r <- mkReg(True);
		Reg#(Bool)                                      fetch <- mkReg(False);
                Reg#(Bool)                               	startRead    <- mkReg(False);		
                Reg#(Bool)                               	_dopool    <- mkReg(False);		
		Bram 						inputFmap    <- mkBram(Banks); 					
		Reg#(Bool)                               	_latch       <- mkReg(False);
		FIFOF#(BramLength) 				_readIndex[Roof][Stencil]; 
		Reg#(UInt#(1)) 					stride[Roof]; 
		//################################################################################################

		for(BramLength i=0; i <Banks; i = i +1 ) begin
			instream[i] <- mkSizedFIFOF(2);
			store[i] <- mkReg(0);
		end

		for(int k = 0; k< (Roof); k = k+1) begin
			collPulse[k] <- mkPulse;
			stride[k] <- mkReg(0);
			_bp[k] <- mkPulse;
			res[k] <- mkReg(0);
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
			recvData[f][k] <- mkReg(0);
			pools[f][k] <- mkPool2;
			convs[f][k] <- mkConv36;
                        _recvEnable[f][k] <- mkPulse;
                        _macPulse[f][k] <- mkPulse;
		end

	
		for(UInt#(10) i =0 ;i<  (Filters * Stencil * Stencil); i = i+1) begin
			coeffs[i] <- mkReg(0);
		end

		rule _CLK ;
			clk <= clk + 1;
		endrule
		
		rule _DRAMStrideFetch( _rebut == False);	
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
					let index = (r1 + i )% (Banks);
					inputFmap.write(d, index, c1);
				 end

				
				
				 if(r1 >= (Stencil-2) && c1 >=  (Stencil)) begin
				 startRead <= True;
				 end
			
				 if(startRead == True)
				 _ena.send;
				_bp0.send;
		endrule

		rule _BRAMfetch (_rebut == False);
			if(DEBUG == 1)
                                        $display("conv|%d", clk);
			_ena.ishigh;
			_bp0.ishigh;

			  	if(c2 ==  extend(img-1)) begin
                                	c2 <= 0;
                          	if (r2 +  (Roof) >=  (Banks)) begin
                                        r2 <= 0;
				end
                                else 
                                        r2 <= r2 +  (Roof);
                          	end
                          	else
                                c2 <= c2 + 1;

			for(BramLength i = 0; i <  (Banks); i = i +1) begin
					   let index  = (r2 + i)% (Banks); 
					   inputFmap.read(index, c2);
			end
			for(BramLength k = 0; k <  (Roof); k = k + 1)
				for(BramLength i = 0; i <  (Stencil); i = i +1) begin
					let index = (r2 + i + k) % (Banks);
					_readIndex[k][i].enq(index);
                         	end
			_bp1.send;
		endrule

		rule _latchData (_rebut == False);
			if(DEBUG == 1)
                        	$display("conv|%d", clk);
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

			if(res[k] ==  extend(img-1)) begin
				res[k] <= 0;
			end
			else
				res[k] <= res[k] + 1;

			if(res[k] >=  (Stencil)-1) begin
				if(res[k] == extend(img-1) || stride[k] == 0) begin
					for(int f = 0; f< Filters; f = f + 1)
                                        	_macPulse[f][k].send;
				end begin
					stride[k] <= (stride[k] + 1);
				end
			end
		endrule



		

		for(int f = 0 ; f<Filters; f = f + 1) begin
					rule pushMac; 
						if(DEBUG == 1 && f == 0 && k == 0 )
                                        		$display("DSP|%d", clk);
						_macPulse[f][k].ishigh;
						Vector#(9, Bit#(64))  _WB = newVector;
						Vector#(9, CoeffType) _FL = newVector;	
						for(int i=0; i< (Stencil*Stencil); i = i+1) begin
							_WB[i] = windowBuffer[k][i];
							_FL[i] = coeffs[f*9 + i];
						end
						convs[f][k].sendP(_WB);
						convs[f][k].sendF(_FL);
						
					endrule


					rule noPool (_dopool == False);
						let d <- convs[f][k].result;
						forward[f][k].enq(d);
					endrule
					
					rule maxPool (_dopool == True);
						let d <- convs[f][k].result; 
						pools[f][k].send(d);
					endrule

					rule deadPooled (_dopool == True);
						let d <- pools[f][k].reduced;
						forward[f][k].enq(d);
					endrule

		end
		end


		rule _reboot (_rebut == True && _FR > 0);
                        _latch <= False;
			_bp0.clean;	
			_bp1.clean;
                        for(int i=0; i<fromInteger(Roof); i = i+1) begin
				instream[i].clear;
				_bp[i].clean;
                                collPulse[i].clean;
				res[i] <= 0;
			        for(int j=0;j<fromInteger(Stencil); j = j + 1)
                                         _readIndex[i][j].clear;
	
			end
			
			for(int f = 0 ; f< Filters; f = f +1)
                        for(int i=0; i<fromInteger(Roof); i = i+1) begin
                                forward[f][i].clear;
				convs[f][i].clean;
				pools[f][i].clean;
                                _recvEnable[f][i].clean;
				_macPulse[f][i].clean;
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

		rule _reboot_mem(_FR == 2 && _rebut == True);
                                inputFmap.clean;
                endrule

		method Action send(Vector#(Roof,Bit#(64)) datas);
				for(int i=0; i< Roof; i = i + 1) begin
					let dat = datas[i];
					instream[i].enq(dat);	
				end
		endmethod
                
		method ActionValue#(Vector#(DW,Bit#(128))) receive if(_rebut == False);
					Vector#(DW,Bit#(128)) datas = newVector;
					for(int f=0; f<Filters; f = f +1)
						for(int k = 0 ; k <Roof; k = k + 1)  begin
                        				let d = forward[f][k].first; forward[f][k].deq;
							datas[f*Roof + k] = d;   
					end
			return datas;
                endmethod
		
		 method Action reboot(Int#(10) im, Bool dP);
			_dopool <= dP;
                        img <= unpack(pack(im));
                        _rebut <= True;
                        _FR <= 2;
                endmethod

                method Action rebootDone if(_FR == 0);
                                _rebut <= False;
                endmethod

        	method Action weights(Vector#(1200,CoeffType) datas);
			for(int i=0; i<Filters ; i = i + 1)
				for(int j=0; j< 9; j = j + 1)
					coeffs[i*9 + j] <= datas[i*9 + j];
		endmethod
	  endmodule: mkStage

endpackage: Stage
                       
