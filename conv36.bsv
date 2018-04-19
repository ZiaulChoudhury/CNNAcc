package conv36;


interface Conv36;
	method Action windowBufffer(Vector#(9, Bit#(64)) datas);
	method Action weights(Vector#(9, CoeffType) filter);
	method ActionValue#(Bit#(256)) result;
endinterface


(*synthesize*)
module mkConv36(Conv36);




	

	
	method Action windowBufffer(Vector#(9, Bit#(64)) datas);
	endmethod

		
	method Action weights(Vector#(9, CoeffType) filter);
	endmethod

	
	method ActionValue#(Bit#(256)) result;
	endmethod
endmodule
endpackage
