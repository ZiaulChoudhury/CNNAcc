package fxpMul;
import MULT_wrapper::*;
import datatypes::*;
import pulse::*;
import FIFOF::*;
import FixedPoint::*;

interface FMUL;
        method Action send(Bit#(16) a, Bit#(16) b);
        method ActionValue#(DataType) receive;
        method Action clear;
endinterface

(*synthesize*)
module mkfxpMul(FMUL);

	Pulse           _step1 <- mkPulse;
        Pulse           _step2 <- mkPulse;
        Pulse           _step3 <- mkPulse;
        Pulse           _step4 <- mkPulse;
        Reg#(Bool)      _step5 <- mkReg(False);
        Reg#(Bool)      _step6 <- mkReg(False);
        Reg#(Bool)      _step7 <- mkReg(False);
        Reg#(Bool)      _step8 <- mkReg(False);
        Pulse           _r <- mkPulse;
	FIFOF#(Bit#(16))  a <- mkFIFOF;
	FIFOF#(Bit#(16))  b <- mkFIFOF;
	FIFOF#(DataType)  out <- mkFIFOF;
	MULT_Ifc      dut  <- mkMULT;
	Reg#(DataType) res <- mkReg(0);
	Reg#(int) clk <- mkReg(0);
   
		rule _CLK;
			clk <= clk + 1;
			
		endrule
		rule start;
			Bit#(16) o1 = a.first; a.deq;
			Bit#(16) o2 = b.first; b.deq;
			dut.put(o1,o2);
			/*if(o2 != 0) begin
			DataType d = unpack(o1);
			$display(" to be multipled output %d @clk %d ", fxptGetInt(d), clk);
			end*/
			_step1.send;
			_step5 <= True;
		endrule

		rule s1 (_step5 == True);
			_step6 <= True;
			_step5 <= False;
                        _step1.ishigh;
			//$display(" ---- 1 ---- %d ", clk);
                        _step2.send;
                endrule

                rule s2 (_step5 == True);
			_step6 <= False;
                        _step2.ishigh;
			_step7 <= True;
			//$display(" ---- 2 ---- %d ",clk);
                        _step3.send;
                endrule

                rule s3 (_step5 == True);
			_step7 <= False;
			_step8 <= True;
                        _step3.ishigh;
			//$display(" --- 3 ---- %d ",clk);
                        _step4.send;
                endrule

                /*rule s4;
                        _step4.ishigh;
                        _step5.send;
                endrule*/

                rule s4 (_step5==True); // && (_step7 == True || _step6 == True || _step8 == True ));
                        _step4.ishigh;
			//_step5 <= False;
			//$display(" --- 4 ---- %d ",clk);
                        Bit#(32) d = dut.read_response();
                        FixedPoint#(12,20)  answer = unpack(d);
			//if(answer != 0)
			//	$display("the answer is %d @clk %d", fxptGetInt(answer), clk);
			out.enq(fxptTruncate(answer));

                endrule


	
   method Action send(Bit#(16) _a, Bit#(16) _b);
		a.enq(_a);
		b.enq(_b);
   endmethod

   method ActionValue#(DataType) receive;
		let d = out.first; out.deq;
		return d;
   endmethod

   method Action clear;
		_step1.clean;
		_step2.clean;
		_step3.clean;
		_step4.clean;
		out.clear;
		a.clear;
		b.clear;
   endmethod

endmodule

endpackage

