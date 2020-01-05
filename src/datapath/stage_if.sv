`include "common.sv"
import common::*;
`include "control/scheduler.sv"
`include "mmu/icache.sv"
`include "mmu/itlb.sv"

module stage_if
(
	input	clk,
	input	rst,

	// IFID interface
	output logic		id_itlb_miss,
	output logic		id_icache_miss,
	output vptr_t		id_pc,
	output word_t		id_instruction,
	output threadid_t	id_thread,
	output word_t		id_rm4,

	// Scheduler
	inout logic[n_threads-1:0]	stalled,

	// Memory
	input logic			mem_rec_en,
	input pptr_t		mem_rec_addr,
	input cacheline_t	mem_rec_cacheline,
	output logic		mem_req_ren,
	output pptr_t		mem_req_addr,

	// TLB
	input logic[n_threads-1:0]	mode,
	input logic					tlbwrite_en,
	input vpn_t 				tlbwrite_vpn,
	input ppn_t 				tlbwrite_ppn,

	// PC of threads (speculative increment of a word outside this module)
	input vptr_t[n_threads-1:0]		pc,

	// Exception handler
	input logic			exc_en,
	input threadid_t	exc_thread
);
	// Flip-Flop registers
	logic		ff_itlb_miss;
	logic		ff_icache_miss;
	vptr_t		ff_pc;
	word_t		ff_instruction;
	threadid_t	ff_thread;
	logic		ff_mem_req_ren;
	pptr_t 		ff_mem_req_addr;

	always_ff @(posedge clk) begin
		id_itlb_miss <= ff_itlb_miss;
		id_icache_miss <= ff_icache_miss;
		id_pc <= ff_pc;
		id_instruction <= ff_instruction;
		id_rm4 <= {31'b0, mode[ff_thread]};
		mem_req_ren <= ff_mem_req_ren;
		mem_req_addr <= ff_mem_req_addr;
	end

	// NOTE Scheduler's output is already flip-floped for "thread" signal
	assign id_thread = ff_thread;

	// Internal signals
	pptr_t 		pc_physical;

	// Instantiate SCHEDULER
	scheduler_roundrobin scheduler_inst (
		.clk(clk),
		.rst(rst),
		.thread(ff_thread),

		.exc_en(exc_en),
		.exc_thread(exc_thread)
	);
	assign ff_pc = pc[ff_thread];

	// Instantiate I-TLB
	itlb itlb_inst (
		.clk(clk),
		.rst(rst),
		.mode(mode[ff_thread]),
		.vaddr(ff_pc),
		.paddr(pc_physical),
		.miss(ff_itlb_miss),
		.write_en(tlbwrite_en),
		.write_vpn(tlbwrite_vpn),
		.write_ppn(tlbwrite_ppn)
	);

	// Instantiate I-CACHE
	icache_directmap icache_inst (
		.clk(clk),
		.rst(rst),

		.thread(ff_thread),

		.paddr(pc_physical),
		.itlb_miss(ff_itlb_miss),

		.miss(ff_icache_miss),
		.data(ff_instruction),

		.mem_rec_en(mem_rec_en),
		.mem_rec_addr(mem_rec_addr),
		.mem_rec_cacheline(mem_rec_cacheline),

		.mem_req_ren(ff_mem_req_ren),
		.mem_req_addr(ff_mem_req_addr),

		.stalled(stalled)
	);
endmodule