`include "common.sv"
import common::*;

// Round-Robin scheduler
module scheduler_roundrobin
(
	input   			clk,
	input   			rst,
	output  threadid_t	thread,

	input logic			exc_en,
	input threadid_t	exc_thread
);
	always_ff @(posedge clk) begin
		if (rst)	thread <= 0;
		else begin
			thread <= (exc_en) ? exc_thread : (thread + 1) % 8;
		end
	end
endmodule

// Round-Robin scheduler with priority encoding on thread stall
module scheduler_priority
(
	input				clk,
	input				rst,

	output	threadid_t					thread,
	input	logic[n_threads-1:0]		stalled,

	input logic			exc_en,
	input threadid_t	exc_thread
);
	always @(posedge clk) begin
		if (rst) thread <= 0;
		else begin
			if (~exc_en) begin
				// Guess next thread is not stalled
				thread <= (thread + 1) % n_threads;

				// Skip to next non-stalled thread
				for (int i = 1; i < n_threads; i++)
					if (~stalled[thread + i % n_threads]) begin
						thread <= (thread + i) % n_threads;
						break;
					end
			end
			else
				thread <= exc_thread;
		end
	end
endmodule