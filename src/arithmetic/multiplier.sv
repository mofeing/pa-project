import common::*;

module multiplier
(
	input	word_t	a,b,
	output	word_t	c
);
	assign {overflow,c} = a * b;
	assign c = a * b;
