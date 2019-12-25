`include "common.sv"
import common::*;

module alu
(
	input	func_t	alu_func,
	input	word_t	a,
	input	word_t 	b,
	output	word_t 	result,
	output	logic	zero
);
	assign zero = result == 0;

	always_comb begin
		case(alu_func)
			func::land: result = a & b;
			func::lor: result = a | b;
			func::lnor: result = ~(a | b);
			func::slt: result = (a < b) ? 1 : 0;
			func::add: result = a + b;
			func::sub: result = a - b;
			default: result = 0;
		endcase
	end

endmodule