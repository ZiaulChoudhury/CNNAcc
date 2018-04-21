package MULT_wrapper;

// ----------------------------------------------------------------
// Interface, as seen by BSV clients

interface MULT_Ifc;
   method Action put(Bit#(16) num1, Bit#(16) num2);
   method Bit#(32) read_response;
endinterface: MULT_Ifc

// ----------------------------------------------------------------
// Import the Verilog module, and let it have an MULT_Ifc interface
// See Section 15 of Reference Guide for syntax and semantics

import "BVI" mkmultfinal =
   module mkMULT (MULT_Ifc);

      // Default clk and no reset passed to the Verilog model
      default_clock clk(clk);
      no_reset;

      // Verilog ports corresponding to method args, results and controls
      method put(a, b) enable(ce);
      method p read_response;

      // Both methods can be called in the same clock,
      // but read_response must logically precede request
      schedule (read_response) SB (put);

      // The response can be read by multiple rules in a clock cycle
      schedule (read_response) CF (read_response);
      // A request can only be made once in a clock cycle
      schedule (put) C (put);
   endmodule  

// ----------------------------------------------------------------

endpackage
