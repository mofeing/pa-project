`include "common.sv"
import common::*;

module controller
(
	input       		clk,
	input				rst,

	/* i-cache */
	input				icache_req_ren,
	input	pptr_t		icache_req_raddr,
	output				icache_rec_en,
	output	pptr_t		icache_rec_addr,
	output	cacheline_t	icache_rec_cacheline,

	/* d-cache */
	input				dcache_req_ren,
	input	pptr_t		dcache_req_raddr,
	input				dcache_req_wen,
	input	pptr_t		dcache_req_waddr,
	input	cacheline_t	dcache_req_wcacheline,
	output				dcache_rec_en,
	output	pptr_t		dcache_rec_addr,
	output	cacheline_t dcache_rec_cacheline,

	/* mem */
	output				mem_req_ren,
	output	pptr_t		mem_req_raddr,
	output				mem_req_wen,
	output	pptr_t		mem_req_waddr,
	output	cacheline_t	mem_req_wcacheline,
	input				mem_rec_en,
	input	pptr_t		mem_rec_addr,
	input	cacheline_t	mem_rec_cacheline
);
	pptr_t queue [n_threads];
	integer head;
	integer tail;

	// Bypass memory receives to caches
	assign icache_rec_en = mem_rec_en;
	assign icache_rec_addr = mem_rec_addr;
	assign icache_rec_cacheline = mem_rec_cacheline;
	assign dcache_rec_en = mem_rec_en;
	assign dcache_rec_addr = mem_rec_addr;
	assign dcache_rec_cacheline = mem_rec_cacheline;

	// Bypass d-cache's write request to memory
	assign mem_req_wen = dcache_req_wen;
	assign mem_req_waddr = dcache_req_waddr;
	assign mem_req_wcacheline = dcache_req_wcacheline;

	// Queue load requests
	always @(posedge clk) begin
		if (rst) begin
			head = 0;
			tail = 0;
		end
		else begin
			// Default values
			mem_req_ren = 0;
			mem_req_wen = 0;

			// Push load requests to queue (d-cache priority)
			if (icache_req_ren) begin
				queue [tail] = icache_req_raddr;
				tail = (tail + 1) % n_threads;
			end
			if (dcache_req_ren) begin
				queue [tail] = dcache_req_raddr;
				tail = (tail + 1) % n_threads;
			end

			// Pop queue and send request to memory
			if (head != tail) begin
				mem_req_ren = 1;
				mem_req_raddr = queue[head];
				head = (head + 1) % n_threads;
			end
		end
	end

endmodule