`include "common.sv"
import common::*;
`include "arithmetic/alu.sv"
`include "arithmetic/multiplier.sv"

module stage_ex
(
	input			clk,
	input			rst,

	// IDEX interface
	input threadid_t			id_thread,
	input logic					id_itlb_miss,
	input logic					id_isvalid,
	input regid_t				id_dst,
	input vptr_t				id_pc,
	input word_t				id_r1,
	input common::mux_a_t		id_a,
	input word_t				id_r2,
	input word_t				id_imm,
	input common::mux_b_t		id_b,
	input common::func_t		id_alu_func,
	input logic					id_flag_mem,
	input logic					id_flag_store,
	input logic					id_flag_isbyte,
	input logic					id_flag_mul,
	input logic					id_flag_reg,
	input logic					id_flag_jump,
	input logic					id_flag_branch,
	input logic					id_flag_iret,
	input common::tlbwrite_t	id_flag_tlbwrite,
	input word_t				id_rm4,

	// EXTL interface
	output threadid_t 			tl_thread,
	output logic 				tl_isvalid,
	output logic 				tl_itlb_miss,
	output vptr_t 				tl_pc,
	output word_t 				tl_data,
	output word_t 				tl_mul,
	output word_t 				tl_r2,
	output regid_t 				tl_dst,
	output logic 				tl_isequal,
	output logic 				tl_flag_mem,
	output logic 				tl_flag_store,
	output logic 				tl_flag_isbyte,
	output logic 				tl_flag_mul,
	output logic 				tl_flag_reg,
	output logic 				tl_flag_jump,
	output logic 				tl_flag_branch,
	output logic 				tl_flag_iret,
	output common::tlbwrite_t 	tl_flag_tlbwrite,
	output word_t				tl_rm4
);

	// Flip-Flop registers
	word_t ff_data;
	word_t ff_mul;
	word_t ff_isequal;

	// Internal signals
	word_t op_a;
	word_t op_b;

	always_ff @(posedge clk) begin
		tl_thread <= id_thread;
		tl_isvalid <= id_isvalid;
		tl_itlb_miss <= id_itlb_miss;
		tl_pc <= id_pc;
		tl_r2 <= id_r2;
		tl_dst <= id_dst;
		tl_flag_mem <= id_flag_mem;
		tl_flag_store <= id_flag_store;
		tl_flag_isbyte <= id_flag_isbyte;
		tl_flag_mul <= id_flag_mul;
		tl_flag_reg <= id_flag_reg;
		tl_flag_jump <= id_flag_jump;
		tl_flag_branch <= id_flag_branch;
		tl_flag_iret <= id_flag_iret;
		tl_flag_tlbwrite <= id_flag_tlbwrite;
		tl_isequal <= id_r1 == id_r2;
		tl_data <= ff_data;
		tl_mul <= ff_mul;
		tl_rm4 <= id_rm4;
	end

	// Instantiate ALU
	assign op_a = (id_a == mux_a::regfile) ? id_r1 : id_pc;
	assign op_b = (id_b == mux_b::regfile) ? id_r2 : id_imm;
	alu alu_instance(
		.alu_func(id_alu_func),
		.a(op_a),
		.b(op_b),
		.result(ff_data),
		.zero() // unconnected
	);

	// Instantiate MULTIPLIER
	multiplier mul_instance(
		.a(id_r1),
		.b(id_r2),
		.c(ff_mul)
	);

endmodule