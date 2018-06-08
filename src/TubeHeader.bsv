package TubeHeader;
import datatypes::*;

typedef struct{

	Integer row; 
	Integer col1; 
	Integer col2; 
	Integer shiftVertical; 
	Integer fifosize;

} ForwardHeader deriving(Eq, Bits);

interface MultirateFilter;
        method Action send(DataType d, Int#(8) index);
        method ActionValue#(DataType) receive(Int#(8) index);
        method ActionValue#(DataType) forwarded(Int#(8) index);
endinterface: MultirateFilter


endpackage: TubeHeader
