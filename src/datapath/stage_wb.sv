`include "common.sv"
import common::*;

module stage_wb (
	input	clk,
	input	rst,

	// TLWB interface
	input threadid_t			tl_thread,
	input logic					tl_isvalid,
	input logic					tl_itlb_miss,
	input logic					tl_dtlb_miss,
	input regid_t				tl_dst,
	input vptr_t				tl_pc,
	input word_t				tl_r2,
	input word_t				tl_data,
	input logic					tl_isequal,
	input word_t				tl_mul,
	input logic 				tl_flag_mul,
	input logic 				tl_flag_reg,
	input logic 				tl_flag_jump,
	input logic 				tl_flag_branch,
	input logic 				tl_flag_iret,
	input common::tlbwrite_t	tl_flag_tlbwrite,

	// Special registers and PC
	output vptr_t	pc[n_threads],
	output word_t	rm0[n_threads],
	output word_t	rm1[n_threads],
	output word_t	rm2[n_threads],
	output word_t	rm4[n_threads],

	// Register file
	output logic[n_threads-1:0]		regfile_wen,
	output regid_t					regfile_addr,
	output word_t					regfile_data,

	// TLB
	output logic	itlb_wen,
	output vpn_t	itlb_vpn,
	output ppn_t	itlb_ppn,
	output logic	dtlb_wen,
	output vpn_t	dtlb_vpn,
	output ppn_t	dtlb_ppn,

	// Scheduler
	output logic		exc_en,
	output threadid_t	exc_thread
);
	vptr_t waiting_pc[n_threads];
	logic exception_state_en;
	threadid_t exception_state_master;
	logic exception_detected;

	always_comb begin
		exception_detected = tl_itlb_miss && tl_dtlb_miss;
		regfile_addr = tl_dst;
		regfile_data = (tl_flag_mul) ? tl_mul : tl_data;

		itlb_vpn = tl_data[19:0];
		itlb_ppn = tl_r2[7:0];
		dtlb_vpn = tl_data[19:0];
		dtlb_ppn = tl_r2[7:0];
	end

	always_ff @(posedge clk) begin
		if (rst) begin
			exception_state_en <= 0;
			foreach (waiting_pc[i])
				waiting_pc[i] = boot_pc[i];
		end
		else if (tl_pc == waiting_pc[tl_thread]) begin // only proceed if input PC is the one we are waiting
			// Retry input PC if there has been an error during execution
			if (~tl_isvalid) begin
				pc[tl_thread] <= tl_pc;

				// Jump to exception handler if not yet in exception state and exception is detected
				if (~exception_state_en && exception_detected) begin
					exception_state_en <= 1;
					exception_state_master <= tl_thread;
					pc[tl_thread] <= exchandler_pc;

					rm0[tl_thread] <= tl_pc;
					if (tl_itlb_miss) begin
						rm1[tl_thread] <= tl_pc;
						rm2[tl_thread] <= exception::itlb_miss;
					end else if (tl_dtlb_miss) begin
						rm1[tl_thread] <= tl_data;
						rm2[tl_thread] <= exception::dtlb_miss;
					end
					rm4[tl_thread] <= 1;
				end
			end

			// Commit only if not in exception state or if in exception state, current thread is the master
			else if (~exception_state_en || tl_thread == exception_state_master) begin
				waiting_pc[tl_thread] <= tl_pc + 4;
				foreach (regfile_wen[i]) regfile_wen[i] <= 0;
				dtlb_wen <= 0;
				itlb_wen <= 0;

				// Jump/branch
				if (tl_flag_jump && (~tl_flag_branch || (tl_flag_branch && tl_isequal))) begin
					pc[tl_thread] <= tl_data;
					waiting_pc[tl_thread] <= tl_data;

					// IRET
					if (tl_flag_iret) begin
						pc[tl_thread] <= rm0[tl_thread];
						rm4[tl_thread] <= 0;
						exception_state_en <= 0;
					end
				end

				// Write to register file (ALU, MUL, LD)
				if (tl_flag_reg) begin
					regfile_wen[tl_thread] <= 1;
				end

				// TLBWRITE
				if (tl_flag_tlbwrite == tlbwrite_signal::itlb) itlb_wen <= 1;
				if (tl_flag_tlbwrite == tlbwrite_signal::dtlb) dtlb_wen <= 1;
			end

			// Force master thread to scheduler if in exception state
			exc_en <= exception_state_en;
			exc_thread <= exception_state_master;
		end
	end

endmodule