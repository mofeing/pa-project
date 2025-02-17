`include "common.sv"
import common::*;

module regfile
(
	input 	logic	clk,
	input	logic	rst,

	input	regid_t	r1_addr,
	output	word_t	r1_data,
	input	regid_t	r2_addr,
	output	word_t	r2_data,
	input	logic	w_enable,
	input	regid_t	w_addr,
	input 	word_t	w_data
);
	word_t register [31:0];

	assign r1_data = register[r1_addr];
	assign r2_data = register[r2_addr];

	always_ff @(posedge clk) begin
		if (rst) begin
			foreach (register[i])
				register[i] = 0;
		end
			else begin
			if (w_enable) begin
				register[w_addr] <= w_data;
			end
		end
	end

endmodule