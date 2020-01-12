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
	output	logic				use_rm1,
	output	logic				use_rm2,

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
		use_rm1 = 0;
		use_rm2 = 0;

		flag_mul = 0;
		flag_mem = 0;
		flag_store = 0;
		flag_jump = 0;
		flag_branch = 0;
		flag_iret = 0;
		flag_reg = 0;
		flag_isbyte = 0;
		flag_tlbwrite = tlbwrite_signal::off;

		case(instruction.op)
			opcode::add : begin
				alu_func = func::add;
				a = mux_a::regfile;
				b = mux_b::regfile;
				flag_reg = 1;
			end
			opcode::addi : begin
				alu_func = func::add;
				a = mux_a::regfile;
				b = mux_b::immediate;
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
				r2 = dst;
			end
			opcode::stw : begin
				alu_func = func::add;
				a = mux_a::regfile;
				b = mux_b::immediate;
				flag_mem = 1;
				flag_store = 1;
				r2 = dst;
			end
			opcode::beq : begin
				alu_func = func::add;
				a = mux_a::pc;
				b = mux_b::immediate;
				flag_jump = 1;
				flag_branch = 1;
				immediate = {17'h0, instruction.fields.b.offset_hi, instruction.fields.b.offset_lo};
			end
			opcode::jump : begin
				alu_func = func::add;
				a = mux_a::regfile;
				b = mux_b::immediate;
				flag_jump = 1;
				immediate = {12'h0, instruction.fields.b.offset_hi, instruction.fields.b.src2, instruction.fields.b.offset_lo};
			end
			opcode::mov_rm1 : begin
				alu_func = func::add;
				a = mux_a::regfile;
				b = mux_b::immediate;
				immediate = 0;
				flag_reg = 1;
				use_rm1 = 1;
			end
			opcode::mov_rm2 : begin
				alu_func = func::add;
				a = mux_a::regfile;
				b = mux_b::immediate;
				immediate = 0;
				flag_reg = 1;
				use_rm2 = 1;
			end
			opcode::tlbwrite_i : begin
				alu_func = func::add;
				flag_tlbwrite = tlbwrite_signal::itlb;
				a = mux_a::regfile;
				b = mux_b::immediate;
				immediate = 0;
			end
			opcode::tlbwrite_d : begin
				alu_func = func::add;
				flag_tlbwrite = tlbwrite_signal::dtlb;
				a = mux_a::regfile;
				b = mux_b::immediate;
				immediate = 0;
			end
			opcode::iret : begin
				flag_iret = 1;
				alu_func = func::add;
			end
			default :
				$display("[decoder] Error: Opcode not recognized (0x%x)", instruction.op);
		endcase
	end
endmodule