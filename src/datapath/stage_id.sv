`include "common.sv"
import common::*;
`include "control/decoder.sv"
`include "control/hzu.sv"

module stage_id
(
	input	clk,
	input	rst,

	// IFID interface
	input logic			if_itlb_miss,
	input logic			if_icache_miss,
	input vptr_t		if_pc,
	input word_t		if_instruction,
	input threadid_t	if_thread,
	input word_t		if_rm4,

	// IDEX interface
	output threadid_t			ex_thread,
	output logic				ex_itlb_miss,
	output logic				ex_isvalid,
	output regid_t				ex_dst,
	output vptr_t				ex_pc,
	output word_t				ex_r1,
	output common::mux_a_t		ex_a,
	output word_t				ex_r2,
	output word_t				ex_imm,
	output common::mux_b_t		ex_b,
	output common::func_t		ex_alu_func,
	output logic				ex_flag_mem,
	output logic				ex_flag_store,
	output logic				ex_flag_isbyte,
	output logic				ex_flag_mul,
	output logic				ex_flag_reg,
	output logic				ex_flag_jump,
	output logic				ex_flag_branch,
	output logic				ex_flag_iret,
	output common::tlbwrite_t	ex_flag_tlbwrite,
	output word_t				ex_rm4,

	// Invalidate thread history
	input	logic		wb_invalidate_en,
	input	threadid_t	wb_invalidate_thread,

	// Register File
	input	word_t[n_threads-1:0]			rm1,
	input	word_t[n_threads-1:0]			rm2,
	input	word_t[n_threads-1:0][32-1:0]	regfile
);
	// Flip-Flop registers
	logic				ff_isvalid;
	regid_t				ff_dst;
	// word_t				ff_r1;
	common::mux_a_t		ff_a;
	// word_t				ff_r2;
	word_t				ff_imm;
	common::mux_b_t		ff_b;
	common::func_t		ff_alu_func;
	logic				ff_flag_mem;
	logic				ff_flag_store;
	logic				ff_flag_isbyte;
	logic				ff_flag_mul;
	logic				ff_flag_reg;
	logic				ff_flag_jump;
	logic				ff_flag_branch;
	logic				ff_flag_iret;
	common::tlbwrite_t	ff_flag_tlbwrite;

	// Internal signals
	regid_t r1;
	regid_t r2;
	logic use_rm1;
	logic use_rm2;

	always_ff @(posedge clk) begin
		ex_thread <= if_thread;
		ex_itlb_miss <= if_itlb_miss;
		ex_isvalid <= ff_isvalid;
		ex_dst <= ff_dst;
		ex_pc <= if_pc;
		ex_r1 <= regfile[if_thread][r1];
		ex_a <= ff_a;
		ex_r2 <= regfile[if_thread][r2];
		ex_imm <= ff_imm;
		ex_b <= ff_b;
		ex_alu_func <= ff_alu_func;
		ex_flag_mem <= ff_flag_mem;
		ex_flag_store <= ff_flag_store;
		ex_flag_isbyte <= ff_flag_isbyte;
		ex_flag_mul <= ff_flag_mul;
		ex_flag_reg <= ff_flag_reg;
		ex_flag_jump <= ff_flag_jump;
		ex_flag_branch <= ff_flag_branch;
		ex_flag_iret <= ff_flag_iret;
		ex_flag_tlbwrite <= ff_flag_tlbwrite;
		ex_rm4 <= if_rm4;

		if (use_rm1)
			ex_r1 <= rm1[if_thread];
		else if (use_rm2)
			ex_r1 <= rm2[if_thread];
	end

	// Intance DECODER
	decoder decoder_inst (
		.instruction(if_instruction),

		.r1(r1),
		.r2(r2),
		.immediate(ff_imm),
		.dst(ff_dst),
		.a(ff_a),
		.b(ff_b),
		.alu_func(ff_alu_func),
		.use_rm1(use_rm1),
		.use_rm2(use_rm2),

		.flag_mem(ff_flag_mem),
		.flag_store(ff_flag_store),
		.flag_isbyte(ff_flag_isbyte),
		.flag_mul(ff_flag_mul),
		.flag_reg(ff_flag_reg),
		.flag_jump(ff_flag_jump),
		.flag_branch(ff_flag_branch),
		.flag_iret(ff_flag_iret),
		.flag_tlbwrite(ff_flag_tlbwrite)
	);

	// Instance HAZARD DETECTION UNIT
	hzu hzu_unit (
		.clk(clk),
		.rst(rst),

		.thread(if_thread),
		.itlb_miss(if_itlb_miss),
		.icache_miss(if_icache_miss),

		.instr(if_instruction),

		.invalidate_en(wb_invalidate_en),
		.invalidate_thread(wb_invalidate_thread),

		.isvalid(ff_isvalid)
	);

endmodule