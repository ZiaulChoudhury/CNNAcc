package conv36;
import datatypes::*;
import Vector::*;
import pulse::*;
import FixedPoint::*;
import mul::*;
import FIFOF::*;
import reduce3::*;

interface Conv36;
	method Action sendP(Vector#(9, Bit#(64)) datas);
	method Action sendF(Vector#(9, CoeffType) filter);
	method ActionValue#(Bit#(128)) result;
	method Action clean;
endinterface


(*synthesize*)
module mkConv36(Conv36);
	
	// ################################## Window Buffer Data #########################
	Reg#(DataType) window[6][6];
	Reg#(CoeffType) coeffs[3][3];
	Pulse _w[4][4][3][3];
	// ###############################################################################


	// #################################### Convolution structures ###################
	Mult _PE[2][4][3][3];
        Reducer3 red[2][4];	
        Pulse _r[2][4];	
        Reg#(DataType) _rv[2][4];	
        FIFOF#(DataType) forward[2][4];	
	//################################################################################

	for(int i=0; i<2; i = i+1)
		for(int j=0; j<4; j = j + 1) begin
			red[i][j] <- mkReducer3;
			forward[i][j] <- mkFIFOF;
			_r[i][j] <- mkPulse;
			_rv[i][j] <- mkReg(0);
			for(int k=0 ; k<3; k = k + 1)
				for(int l=0; l <3; l = l+1) begin	
					_PE[i][j][k][l] <- mkMult;
					_w[i][j][k][l] <- mkPulse;
				end
		end
	

	for(int i=0 ;i< 3; i = i+1)
		for(int j=0;j<3; j = j + 1)
			if(i == 1 && j == 1)
			coeffs[i][j] <- mkReg(1);
			else
			coeffs[i][j] <- mkReg(0);

	
	for(int i=0 ;i< 6; i = i+1)
		for(int j=0; j<6; j = j+1)
			window[i][j] <- mkReg(0);	

	for(int r= 0; r <2; r= r + 1)
		for(int c = 0; c <4; c = c+1) begin
			for(int i=0 ;i< 3; i = i+1)
				for(int j=0; j<3; j = j+1)
				rule _pushMAC;
					_w[r][c][i][j].ishigh;
					_PE[r][c][i][j].a(window[r+i][c+j], False);
					_PE[r][c][i][j].b(coeffs[i][j]);							
				endrule
				
				rule getResult;
					Vector#(9, DataType) res = newVector;
					for(int i=0 ;i< 3; i = i+1)
                                		for(int j=0; j<3; j = j+1)
						res[i*3 + j] <- _PE[r][c][i][j].out;

					red[r][c].send(res);
				endrule 

				rule getComputeResult;
					let d <- red[r][c].reduced;
					forward[r][c].enq(d);
				endrule 

				
				rule store;
					let d = forward[r][c].first; forward[r][c].deq;
					_rv[r][c] <= d;
					_r[r][c].send;
				endrule
	end

	
	method Action sendP(Vector#(9, Bit#(64)) datas);
		for(int i= 0 ;i<3 ; i = i +1)
			for(int j=0; j<3; j = j +1) begin
			Vector#(4, DataType) bundle = unpack(datas[i + j*3]);
			for(int k = 0; k <2; k = k+1)
				for(int l = 0; l<2; l = l + 1) begin
					window[i*2+k][j*2 + l] <= bundle[k*2 + l];
				end
			end

		for(int r= 0; r <4; r= r + 1)
                	for(int c = 0; c <4; c = c+1)
                        	for(int i=0 ;i< 3; i = i+1)
                                	for(int j=0; j<3; j = j+1)
						_w[r][c][i][j].send;
	endmethod

		
	method Action sendF(Vector#(9, CoeffType) filter);
	endmethod
	
	method ActionValue#(Bit#(128)) result;
			Vector#(8, DataType) out = newVector;
			for(int i=0;i<2; i = i +1)
				for(int j=0; j<4; j = j+1) begin
				_r[i][j].ishigh;
				out[i*4 + j] = _rv[i][j];
				end
			return pack(out);
	endmethod

	method Action clean;
			for(int i=0; i<2; i = i+1)
                	for(int j=0; j<4; j = j + 1) begin
                        	red[i][j].clean;
                        	forward[i][j].clear;
                        	_r[i][j].clean;
                        	for(int k=0 ; k<3; k = k + 1)
                                	for(int l=0; l <3; l = l+1) begin 
                                        	_PE[i][j][k][l].clean;
                                        	_w[i][j][k][l].clean;
                                	end
                	end

	endmethod
endmodule
endpackage
