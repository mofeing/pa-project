`include "common.sv"
import common::*;

parameter n_stages = 8;

module decoder
(
	input	common::instr_t	instruction,

	output	regid_t				r1,
	output	regid_t				r2,
	output	word_t				immediate,
	output	regid_t				dst,
	output	common::mux_a_t		a,
	output	common::mux_b_t		b,
	output	common::func_t		alu_func,

	// Flags
	output	logic				flag_mem,
	output	logic				flag_store,
	output	logic				flag_isbyte,
	output	logic				flag_mul,
	output	logic				flag_reg,
	output	logic				flag_jump,
	output	logic				flag_branch,
	output	logic				flag_iret,
	output	common::tlbwrite_t	flag_tlbwrite
);

	always_comb begin
		// Default values
		r1 = instruction.fields.r.src1;
		r2 = instruction.fields.r.src2;
		immediate = {17'b0, instruction.fields.m.immediate};
		dst = instruction.fields.r.dst;

		flag_mul = 0;
		flag_mem = 0;
		flag_store = 0;
		flag_jump = 0;
		flag_branch = 0;
		flag_iret = 0;
		flag_reg = 0;
		flag_isbyte = 0;
		flag_tlbwrite = tlbwrite_signal::off;

		// TODO invalid instruction exception
		case(instruction.op)
			opcode::add : begin
				alu_func = func::add;
				a = mux_a::regfile;
				b = mux_b::regfile;
				flag_reg = 1;
			end
			opcode::sub : begin
				alu_func = func::sub;
				a = mux_a::regfile;
				b = mux_b::regfile;
				flag_reg = 1;
			end
			opcode::mul : begin
				flag_mul = 1;
				flag_reg = 1;
			end
			opcode::ldb : begin
				alu_func = func::add;
				a = mux_a::regfile;
				b = mux_b::immediate;
				flag_mem = 1;
				flag_reg = 1;
				flag_isbyte = 1;
			end
			opcode::ldw : begin
				alu_func = func::add;
				a = mux_a::regfile;
				b = mux_b::immediate;
				flag_mem = 1;
				flag_reg = 1;
			end
			opcode::stb : begin
				alu_func = func::add;
				a = mux_a::regfile;
				b = mux_b::immediate;
				flag_mem = 1;
				flag_store = 1;
				flag_isbyte = 1;
			end
			opcode::stw : begin
				alu_func = func::add;
				a = mux_a::regfile;
				b = mux_b::immediate;
				flag_mem = 1;
				flag_store = 1;
			end
			opcode::beq : begin
				alu_func = func::add;
				a = mux_a::pc;
				b = mux_b::immediate;
				flag_jump = 1;
				flag_branch = 1;
			end
			opcode::jump : begin
				alu_func = func::add;
				a = mux_a::regfile;
				b = mux_b::immediate;
				flag_jump = 1;
			end
			opcode::mov : begin
				alu_func = func::land;
				a = mux_a::regfile;
				b = mux_b::regfile;
				flag_reg = 1;
				// r2 = r1;
			end
			opcode::tlbwrite : begin
				alu_func = func::add;
				flag_tlbwrite = (instruction.fields.b.offset_lo == 0) ? tlbwrite_signal::itlb : tlbwrite_signal::dtlb;
			end
			opcode::iret : begin
				flag_iret = 1;
				alu_func = func::add;
			end
		endcase
	end
endmodule