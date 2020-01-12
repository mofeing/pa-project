`include "common.sv"
import common::*;

// Instruction history
typedef struct packed {
	logic valid;
	threadid_t thread;
	instr_t instr;
} history_entry_t;

function logic has_src2 (common::opcode_t op);
	return (op == opcode::add) || (op == opcode::sub) || (op == opcode::mul) || (op == opcode::beq) || (op == opcode::tlbwrite_i) || (op == opcode::tlbwrite_d);
endfunction

function logic has_dst (common::opcode_t op);
	return (op == opcode::add) || (op == opcode::sub) || (op == opcode::mul) || (op == opcode::ldb) || (op == opcode::ldw) || (op == opcode::mov_rm1) || (op == opcode::mov_rm2) || (op == opcode::addi);
endfunction

module hzu
#(
	parameter N = 5
)
(
	input				clk,
	input				rst,

	input	threadid_t	thread,
	input	logic		itlb_miss,
	input	logic		icache_miss,

	input	instr_t		instr,

	input	logic		invalidate_en,
	input	threadid_t	invalidate_thread,

	output	logic		isvalid
);
	history_entry_t history [N];
	logic issrc2kind;

	always_comb begin
		if (rst || itlb_miss || icache_miss) isvalid = 0;
		else begin
			isvalid = 1;
			issrc2kind = has_src2(instr.op);

			foreach (history[i])
				if (history[i].valid && history[i].thread == thread && (
					// dst and src1 do not clash
					(has_dst(history[i].instr.op) && instr.fields.r.src1 == history[i].instr.fields.r.dst)
					// dst and src2 do not clash
					|| (has_dst(history[i].instr.op) && issrc2kind && instr.fields.r.src2 == history[i].instr.fields.r.dst)
				)) begin
					isvalid = 0;
					break;
				end
		end
	end

	always_ff @(posedge clk) begin
		if (rst)
			foreach (history[i])
				history[i].valid = 0;
		else begin
			// Invalidate thread history
			if (invalidate_en) begin
				foreach (history[i])
					if (history[i].thread == invalidate_thread)
						history[i].valid = 0;
			end

			// Update history
			history[0].valid <= isvalid;
			history[0].thread <= thread;
			history[0].instr <= instr;
			for (int i = 1; i < $size(history); i++)
				history[i] <= history[i-1];
		end
	end
endmodule