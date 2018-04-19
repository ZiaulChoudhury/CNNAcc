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

#define IMG 16
#define Filters 8
#define Roof 2
#define Stencil 3
#define Banks 4
#define DW 16
#define DEBUG 0

interface Convolver;
        //method Action weights(Vector#(1200,CoeffType) datas);
        method Action send(Vector#(Roof,DataType) datas);
        method ActionValue#(Vector#(DW,DataType)) receive;
        method Action reboot(Int#(10) img);
        method Action rebootDone;
endinterface: Convolver


(*synthesize*) 
	module mkStage(Convolver);

		
		//############################################# INITS ############################################
		Reg#(Bool) _rebut <- mkReg(False);
                Reg#(UInt#(8)) _FR <- mkReg(0);	
		Reg#(DataType) windowBuffer[Roof][Stencil*Stencil];
		Reg#(CoeffType) coeffs[Filters*Stencil*Stencil];
		Reg#(UInt#(10)) res[Roof];
		Integer _DSP = Filters * Roof * Stencil * Stencil;
		Reg#(Int#(32)) clk <- mkReg(0);
		Reg#(UInt#(10))  img <- mkReg(16);
		FIFOF#(DataType) instream[Banks];
		Reg#(DataType) data[Roof][Stencil];
		Reg#(DataType) store[Banks];
		FIFOF#(DataType) forward[Filters][Roof];
		Mult _PE[_DSP];
		Pulse _macPulse[Filters][Roof][Stencil*Stencil];
		Pulse 	collPulse[Roof];
		Pulse 	_ena <- mkPulse; 
		Pulse 	_l <- mkPulse; 
		Pulse                                   	_recvEnable[Filters][Roof];
		Pulse                                   	_forEnable[Filters][Roof];
		Pulse                                           _bp[Roof];
                Pulse                                           _bp0 <- mkPulse;
                Pulse                                           _bp1 <- mkPulse;
                Pulse                                           _bp2 <- mkPulse;
		Reg#(DataType)                          	recvData[Filters][Roof];
                Reg#(BramLength)                           	r2 <- mkReg(0);
                Reg#(BramLength)                           	r1 <- mkReg(0);
		Reg#(BramWidth) 				c2 <- mkReg(0);
		Reg#(BramWidth) 				c1 <- mkReg(0);
		Reg#(Bool)                                      fetch <- mkReg(False);
                Reg#(Bool)                               	startRead    <- mkReg(False);		
		Reducer3 red[Filters][Roof];	
		Bram 						inputFmap    <- mkBram(Banks); 					
		Reg#(Bool)                               	_latch       <- mkReg(False);
		FIFOF#(BramLength) 				_readIndex[Roof][Stencil]; 
		//################################################################################################


		for(int i = 0; i<  fromInteger(_DSP); i = i+1)
			_PE[i] <- mkMult;


		for(BramLength i=0; i <Banks; i = i +1 ) begin
			instream[i] <- mkSizedFIFOF(2);
			store[i] <- mkReg(0);
		end

		for(int k = 0; k< (Roof); k = k+1) begin
			collPulse[k] <- mkPulse;
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
                        _recvEnable[f][k] <- mkPulse;
			red[f][k] <- mkReducer3;
			for(int i= 0;i < (Stencil*Stencil); i = i+1)
                                _macPulse[f][k][i] <- mkPulse;
		end

	
		//######################### CHANGE ########################
		for(UInt#(10) i =0 ;i < Filters; i = i+1) begin
			for(UInt#(10) j =0 ;j< Stencil * Stencil; j = j+1)
				if(j == 4)
				coeffs[9*i + j] <- mkReg(1);
				else
				coeffs[9*i + j] <- mkReg(0);
		end
		//##########################################################
		
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
					inputFmap.write(d, index, c1);
				 end

				 if(r1 >=  (Stencil)-1 && c1 >=  (Stencil))
				 startRead <= True;
			
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
                          	if (r2 +  (Roof) >=  (Banks))
                                        r2 <= 0;
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
					let index = (r2 + i + k)% (Banks);
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

			if(res[k] ==  extend(img-1))
				res[k] <= 0;
			else
				res[k] <= res[k] + 1;

			if(res[k] >=  (Stencil)-1)
				for(int f = 0; f< Filters; f = f + 1)
				for(int i=0;i< (Stencil*Stencil);i = i+1)
                                        	_macPulse[f][k][i].send;
		endrule


		

		for(int f = 0 ; f<Filters; f = f + 1) begin
			for(int i=0; i< (Stencil*Stencil); i = i+1)
					rule pushMac; 
						if(DEBUG == 1 && f == 0 && i == 0 && k == 0)
                                        		$display("DSP|%d", clk);
						_macPulse[f][k][i].ishigh;
						 let id = f*18 + k*(Stencil*Stencil)+i;
						if( i == 0 && f == 0 && k == 0)
							$display(" %d %d %d %d %d %d %d %d %d ", fxptGetInt(windowBuffer[0][0]), fxptGetInt(windowBuffer[0][1]), fxptGetInt(windowBuffer[0][2]), fxptGetInt(windowBuffer[0][3]), fxptGetInt(windowBuffer[0][4]), fxptGetInt(windowBuffer[0][5]), fxptGetInt(windowBuffer[0][6]), fxptGetInt(windowBuffer[0][7]), fxptGetInt(windowBuffer[0][8]));
						if(id == 0)
							_PE[id].a(windowBuffer[k][i], True);
						else
							_PE[id].a(windowBuffer[k][i], False);
						_PE[id].b(coeffs[f*9 + i]);

					endrule

		rule getResult;
			if(DEBUG == 1 && f == 0 && k == 0)
                                        $display("DSP|%d", clk);
                        Vector#(9,DataType) datas = newVector;
			for(int i=0; i< (Stencil*Stencil); i = i+1) begin
                        	let id = f*18 + k*(Stencil*Stencil)+i;
                        	let d <- _PE[id].out;
                                datas[i] = d;
			end
			red[f][k].send(datas);
                endrule


		rule getComputeResult; 
			if(DEBUG == 1 && f == 0 && k == 0)
                                        $display("conv|%d", clk);
			let d <- red[f][k].reduced;
			forward[f][k].enq(d);
		endrule


		/*rule receivePort;
			if(DEBUG == 1 && f == 0 && k == 0)
                                        $display("conv|%d", clk);
				  let d = forward[f][k].first; forward[f][k].deq;
                                  recvData[f][k] <= d;
                                 _recvEnable[f][k].send;
                endrule*/

		
		end
		end


		rule _reboot (_rebut == True && _FR > 0);
                        _latch <= False;
                        for(int i = 0; i< fromInteger(_DSP); i = i+1)
                                _PE[i].clean;

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
                                red[f][i].clean;
                                _recvEnable[f][i].clean;
				for(Int#(8) j=0;j<fromInteger(Stencil*Stencil);j = j+1)
					_macPulse[f][i][j].clean;
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

		method Action send(Vector#(Roof,DataType) datas);
				for(int i=0; i< Roof; i = i + 1) begin
					let dat = datas[i];
					instream[i].enq(dat);	
				end
		endmethod
                
		method ActionValue#(Vector#(DW,DataType)) receive if(_rebut == False);
					Vector#(DW,DataType) datas = newVector;
					for(int f=0; f<Filters; f = f +1)
						for(int k = 0 ; k <Roof; k = k + 1)  begin
                        				let d = forward[f][k].first; forward[f][k].deq; //_recvEnable[f][k].ishigh;
							datas[f*Roof + k] = d;  //recvData[f][k]; 
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

        	/*method Action weights(Vector#(1200,CoeffType) datas);
			for(int i=0; i<Filters ; i = i + 1)
				for(int j=0; j< 9; j = j + 1)
					coeffs[i*9 + j] <= datas[i*9 + j];
		endmethod*/
	  endmodule: mkStage

endpackage: Stage
                       
