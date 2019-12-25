`include "common.sv"
import common::*;

module multiplier
(
	input	word_t	a,b,
	output	word_t	c
);
	assign c = a * b;
endmodule