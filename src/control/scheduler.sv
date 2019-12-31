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
		if (rst)	thread = 0;
		else begin
			thread = (exc_en) ? exc_thread : (thread + 1) % 8;
		end
	end
endmodule

// Round-Robin scheduler with priority encoding on thread stall
module scheduler_priority
(
	input				clk,
	input				rst,

	output	threadid_t	thread,
	input	logic		stalled[n_threads-1:0],

	input logic			exc_en,
	input threadid_t	exc_thread
);
	threadid_t guess;
	integer i;

	// Start first thread on reset
	always @(posedge clk) begin
		if (rst)
			guess = 0;
		else begin
			if (~exc_en) begin
				// Guess next thread is not stalled
				thread = guess;

				// Skip to next non-stalled thread
				for (i = n_threads-1; i >= 1; i = i - 1) begin
					integer j = (i + guess) % n_threads;
					if (stalled[j] == 0)
						thread = j;
				end

				// Update next guess
				guess = (thread + 1) % n_threads;
			end
			else
				thread = exc_thread;
		end
	end
endmodule