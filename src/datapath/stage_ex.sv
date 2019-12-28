`include "common.sv"
import common::*;
`include "datapath/datapath.sv"
`include "arithmetic/alu.sv"
`include "arithmetic/multiplier.sv"

module stage_ex
(
	input			clk,
	input			rst,

	input	IDEX	in,
	output	EXTL	out
);
	word_t op_a;
	word_t op_b;
	word_t data;
	word_t mul;

	always_ff @(posedge clk) begin
		if (rst) begin
			out.data = 0;
			out.mul = 0;
			out.is_equal = 0;
		end
		else begin
			out.data <= data;
			out.mul <= mul;
			out.is_equal <= (in.r1 == in.r2);

			// Bypass
			out.thread <= in.thread;
			out.is_valid <= in.is_valid;
			out.itlb_miss <= in.itlb_miss;
			out.dst <= in.dst;
			out.pc <= in.pc;
			out.r2 <= in.r2;
			out.flag_mem <= in.flag_mem;
			out.flag_store <= in.flag_store;
			out.flag_isbyte <= in.flag_isbyte;
			out.flag_mul <= in.flag_mul;
			out.flag_reg <= in.flag_reg;
			out.flag_jump <= in.flag_jump;
			out.flag_branch <= in.flag_branch;
			out.flag_iret <= in.flag_iret;
			out.flag_tlbwrite <= in.flag_tlbwrite;
		end
	end

	// Instantiate ALU
	assign op_a = (in.a == mux_a::regfile) ? in.r1 : in.pc;
	assign op_b = (in.b == mux_b::regfile) ? in.r2 : in.imm;
	alu alu_instance(
		.alu_func(in.alu_func),
		.a(op_a),
		.b(op_b),
		.result(data),
		.zero() // unconnected
	);

	// Instantiate MULTIPLIER
	mul mul_instance(
		.a(in.r1),
		.b(in.r2),
		.c(mul)
	);

endmodule