package conv36;
import FIFOF::*;
import datatypes::*;
import Vector::*;
import pulse::*;
import FixedPoint::*;
import mul::*;
import FIFOF::*;

interface Conv36;
	method Action sendP(Vector#(9, Bit#(64)) datas);
	method Action sendF(Vector#(9, Bit#(64)) filter);
	method ActionValue#(DataType) result;
	method Action clean;
endinterface


(*synthesize*)
module mkConv36(Conv36);
	
	//################################## DataStructures  #########################	
	FIFOF#(Bit#(576)) _inputQ <- mkFIFOF; 
	Reg#(DataType) window[4][9];
	Reg#(Bit#(1)) wp[4][9];
	Reg#(Bit#(1)) wc[4][9];
	Reg#(Bool) w <- mkReg(False);
	Reg#(DataType) accumulator1[4][9];
	Reg#(DataType) accumulator2[4][3];
	Reg#(DataType) accumulator3[4];
	Reg#(DataType) acc4 <- mkReg(0);
	Reg#(DataType) acc5 <- mkReg(0);
	Reg#(DataType) acc6 <- mkReg(0);
	Reg#(CoeffType) coeffs[4][9];
	Pulse a0[4];
	Pulse a1[4];
	Reg#(int) clk <- mkReg(0);
	Reg#(Bit#(1)) p0 <- mkReg(0);
	Reg#(Bit#(1)) c0 <- mkReg(0);
	Reg#(Bit#(1)) p1 <- mkReg(0);
        Reg#(Bit#(1)) c1 <- mkReg(0);	
	Reg#(Bit#(1)) p2 <- mkReg(0);
        Reg#(Bit#(1)) c2 <- mkReg(0);	
	Reg#(Bit#(1)) p3 <- mkReg(0);
        Reg#(Bit#(1)) c3 <- mkReg(0);
	Mult _PE[4][9];
	FIFOF#(DataType) _outQ <- mkFIFOF;
	for(int i=0; i<4; i = i + 1) begin
		a0[i]  <- mkPulse;
		a1[i]  <- mkPulse;
		for(int j= 0; j<9; j = j + 1) begin
			window[i][j] <- mkReg(0);
			
			if ( j== 4)
			coeffs[i][j] <- mkReg(1);
			else	
			coeffs[i][j] <- mkReg(0);
			
			_PE[i][j] <- mkMult;
			wp[i][j] <- mkReg(0);
			wc[i][j] <- mkReg(0);
			accumulator1[i][j] <- mkReg(0);
		end
		for(int k=0; k<3; k = k +1)
			accumulator2[i][k] <- mkReg(0);
		accumulator3[i] <- mkReg(0);
	end
	//##################################################################################

	rule _clk;
		clk <= clk + 1;
	endrule

	rule _input_decompose;
		let  packet = _inputQ.first; _inputQ.deq;
		Vector#(9, Bit#(64)) wb = unpack(packet);
		for(int _Elem = 0; _Elem < 9 ; _Elem  = _Elem + 1) begin
			Vector#(4, Bit#(16)) _block = unpack(wb[_Elem]);
			for(int _depth = 0; _depth < 4; _depth = _depth + 1) begin
				window[_depth][_Elem] <= unpack(_block[_depth]);
				wp[_depth][_Elem] <= ~wp[_depth][_Elem];
				
			end
		end	
	endrule

	
	
	for(int _depth= 0; _depth < 4; _depth = _depth + 1) begin
		for(int _Elem=0 ;_Elem< 9; _Elem = _Elem + 1) begin
				rule _pushMAC((wc[_depth][_Elem] ^ wp[_depth][_Elem]) == 1);
					 wc[_depth][_Elem] <= wp[_depth][_Elem];
					_PE[_depth][_Elem].a(window[_depth][_Elem]);
					_PE[_depth][_Elem].b(coeffs[_depth][_Elem]);
				endrule
				
				rule _ac1;
					let d <- _PE[_depth][_Elem].out;
					accumulator1[_depth][_Elem] <= d;
					if(_Elem == 0)
						a0[_depth].send;
				endrule
		end 

				rule _ac2;
					a0[_depth].ishigh;	
                                        accumulator2[_depth][0] <= fxptTruncate(fxptAdd(accumulator1[_depth][0],fxptAdd(accumulator1[_depth][3], accumulator1[_depth][4])));
                                        accumulator2[_depth][1] <= fxptTruncate(fxptAdd(accumulator1[_depth][1],fxptAdd(accumulator1[_depth][5], accumulator1[_depth][6])));
                                        accumulator2[_depth][2] <= fxptTruncate(fxptAdd(accumulator1[_depth][2],fxptAdd(accumulator1[_depth][7], accumulator1[_depth][8])));	
					a1[_depth].send;
                                endrule

				rule _ac3;
					a1[_depth].ishigh;
					DataType d = fxptTruncate(fxptAdd(accumulator2[_depth][0], fxptAdd(accumulator2[_depth][1], accumulator2[_depth][2])));
					accumulator3[_depth] <= d;
					if(_depth == 0)
						p0 <= ~p0;		
				endrule
	end

				rule _sums0 ((c0 ^ p0) == 1);
					c0 <= p0;
					acc4 <=  fxptTruncate(fxptAdd(accumulator3[0],accumulator3[1]));
					acc5 <=  fxptTruncate(fxptAdd(accumulator3[2],accumulator3[3]));
					p1 <= ~p1;
				endrule 
				
				rule _sums1 ((c1 ^ p1) == 1);
					c1 <= p1;
					acc6 <= fxptTruncate(fxptAdd(acc4,acc5));	
					p2 <= ~p2; 
				endrule

				rule _outFifo((c2 ^ p2) == 1);
					c2 <= p2;
					_outQ.enq(acc6);
				endrule


				rule _clean((c3 ^ p3) == 1);
					c3 <= p3;
					for(int i=0; i<4; i = i + 1) begin
                				a0[i].clean;
                				a1[i].clean;
                				for(int j= 0; j<9; j = j + 1)
                        				_PE[i][j].clean;
					end
					_outQ.clear;
					_inputQ.clear;
				endrule
	
	
	method Action sendP(Vector#(9, Bit#(64)) datas);
		_inputQ.enq(pack(datas));	
	endmethod

		
	method Action sendF(Vector#(9, Bit#(64)) filter);
			/*for(int j=0; j<9; j= j + 1) begin
					Vector#(4, CoeffType) d = unpack(filter[j]);
					coeffs[0][j] <= d[0];
					coeffs[1][j] <= d[1];
					coeffs[2][j] <= d[2];
					coeffs[3][j] <= d[3];				
			end*/
	endmethod
	
	method ActionValue#(DataType) result;
			let d = _outQ.first; _outQ.deq;
			return d;
	endmethod

	method Action clean;
		p3 <= ~p3;
	endmethod
	
endmodule
endpackage
