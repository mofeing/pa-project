`include "common.sv"
import common::*;

// Instruction history
typedef struct packed {
	logic valid;
	threadid_t thread;
	instr_t instr;
} history_entry_t;

function logic has_src2 (common::opcode_t op);
	return (op == opcode::add) || (op == opcode::sub) || (op == opcode::mul) || (op == opcode::beq) || (op == opcode::tlbwrite);
endfunction

function logic has_dst (common::opcode_t op);
	return (op == opcode::add) || (op == opcode::sub) || (op == opcode::mul) || (op == opcode::ldb) || (op == opcode::ldw) || (op == opcode::mov);
endfunction

module hzu
(
	input				clk,
	input				rst,

	input	threadid_t	thread,
	input	logic		itlb_miss,
	input	logic		icache_miss,

	input	instr_t		instr,

	output	logic		isvalid
);
	history_entry_t history [8];
	logic drace;
	logic issrc2kind;

	assign isvalid = history[0].valid;

	always_ff @(posedge clk) begin
		if (rst) begin
			foreach (history[i])
				history[i].valid = 0;

			isvalid = 0;
		end
		else begin
			// Move up history
			for (int i = 0; i < $size(history)-1; i++)
				history[i+1] = history[i];

			// Save instruction in history
			history[0].valid = 1; // speculative, overwritten in the end
			history[0].thread = thread;
			history[0].instr = instr;

			// Check for data-race
			drace = 0;
			issrc2kind = has_src2(history[0].instr.op);
			for (int i = 1; i < $size(history); i++)
				if (history[i].valid && history[i].thread == thread && (
						// dst and src1 do not clash
						(has_dst(history[i].instr.op) && history[0].instr.fields.r.src1 == history[i].instr.fields.r.dst)
						// dst and src2 do not clash
						|| (has_dst(history[i].instr.op) && issrc2kind && history[0].instr.fields.r.src2 == history[i].instr.fields.r.dst)
					)
				)
					drace = 1;

			// Design artifact: no store/load after store
			if (history[1].valid
				&& (
					history[1].instr.op == opcode::stb
					|| history[1].instr.op == opcode::stw
					)
				&& (
					history[0].instr.op == opcode::stb
					|| history[0].instr.op == opcode::stw
					|| history[0].instr.op == opcode::ldb
					|| history[0].instr.op == opcode::ldw
					)
				)
				isvalid = 0;

			// Commit isvalid if no I-TLB exception and I-cache miss
			if (itlb_miss || icache_miss || drace) begin
				history[0].valid = 0;
			end
		end
	end


endmodule