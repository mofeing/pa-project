`include "common.sv"
import common::*;
`include "mmu/dtlb.sv"
`include "mmu/dcache.sv"

module stage_tl
(
	input			clk,
	input			rst,

	// EXTL interface
	input threadid_t 			ex_thread,
	input logic 				ex_isvalid,
	input logic 				ex_itlb_miss,
	input vptr_t 				ex_pc,
	input word_t 				ex_data,
	input word_t 				ex_mul,
	input word_t 				ex_r2,
	input regid_t 				ex_dst,
	input logic 				ex_isequal,
	input logic 				ex_flag_mem,
	input logic 				ex_flag_store,
	input logic 				ex_flag_isbyte,
	input logic 				ex_flag_mul,
	input logic 				ex_flag_reg,
	input logic 				ex_flag_jump,
	input logic 				ex_flag_branch,
	input logic 				ex_flag_iret,
	input common::tlbwrite_t 	ex_flag_tlbwrite,
	input word_t				ex_rm4,

	// TLWB interface
	output threadid_t			wb_thread,
	output logic				wb_isvalid,
	output logic				wb_itlb_miss,
	output logic				wb_dtlb_miss,
	output regid_t				wb_dst,
	output vptr_t				wb_pc,
	output word_t				wb_r2,
	output word_t				wb_data,
	output logic				wb_isequal,
	output word_t				wb_mul,
	output logic 				wb_flag_mul,
	output logic 				wb_flag_reg,
	output logic 				wb_flag_jump,
	output logic 				wb_flag_branch,
	output logic 				wb_flag_iret,
	output common::tlbwrite_t	wb_flag_tlbwrite,
	output logic				wb_flag_store,
	output logic				wb_flag_isbyte,

	// Stalled bits
	output logic[n_threads-1:0]	stalled,

	// Memory interface
	output	logic		mem_req_ren,
	output	pptr_t		mem_req_raddr,
	output	logic		mem_req_wen,
	output	pptr_t		mem_req_waddr,
	output	cacheline_t	mem_req_wcacheline,
	input	logic		mem_rec_en,
	input	pptr_t		mem_rec_addr,
	input	cacheline_t mem_rec_cacheline,

	// TLBWRITE interface
	input	logic	tlbwrite_en,
	input	vpn_t	tlbwrite_vpn,
	input	ppn_t	tlbwrite_ppn,

	// STORE interface
	input	logic	store_en,
	input	logic	store_isbyte,
	input	pptr_t	store_addr,
	input	word_t	store_data
);
	// Flip-Flop registers
	logic ff_dtlb_miss;
	logic ff_isvalid;
	word_t ff_data;

	// Internal signals
	logic dcache_miss;
	word_t dcache_data;
	pptr_t paddr;

	always_comb begin
		ff_isvalid = (ex_flag_mem) ? (ex_isvalid && ~ff_dtlb_miss && ~dcache_miss) : ex_isvalid;
		ff_data = (ex_flag_mem && ~ex_flag_store) ? dcache_data : ex_data;
	end

	always_ff @(posedge clk) begin
		wb_thread <= ex_thread;
		wb_isvalid <= ff_isvalid;
		wb_itlb_miss <= ex_itlb_miss;
		wb_dtlb_miss <= ff_dtlb_miss;
		wb_dst <= ex_dst;
		wb_pc <= ex_pc;
		wb_r2 <= ex_r2;
		wb_data <= ff_data;
		wb_isequal <= ex_isequal;
		wb_mul <= ex_mul;
		wb_flag_mul <= ex_flag_mul;
		wb_flag_reg <= ex_flag_reg;
		wb_flag_jump <= ex_flag_jump;
		wb_flag_branch <= ex_flag_branch;
		wb_flag_iret <= ex_flag_iret;
		wb_flag_tlbwrite <= ex_flag_tlbwrite;
		wb_flag_store <= ex_flag_store;
		wb_flag_isbyte <= ex_flag_isbyte;
	end

	// Instantiate D-TLB
	dtlb dtlb_inst(
		.clk(clk),
		.rst(rst),

		.mode(ex_rm4[0]),
		.vaddr(ex_data),
		.paddr(paddr),

		.miss(ff_dtlb_miss),

		.write_en(tlbwrite_en),
		.write_vpn(tlbwrite_vpn),
		.write_ppn(tlbwrite_ppn),

		.is_valid(ex_isvalid),
		.flag_mem(ex_flag_mem)
	);

	// Instantiate D-CACHE
	dcache_directmap dcache_inst(
		.clk(clk),
		.rst(rst),

		.thread(ex_thread),

		.paddr(paddr),
		.isvalid(ex_isvalid),
		.miss(dcache_miss),
		.data(dcache_data),

		.dtlb_miss(ff_dtlb_miss),
		.flag_mem(ex_flag_mem && ex_isvalid),
		.flag_store(ex_flag_store),
		.flag_isbyte(ex_flag_isbyte),

		.mem_req_ren(mem_req_ren),
		.mem_req_raddr(mem_req_raddr),
		.mem_req_wen(mem_req_wen),
		.mem_req_waddr(mem_req_waddr),
		.mem_req_wcacheline(mem_req_wcacheline),
		.mem_rec_en(mem_rec_en),
		.mem_rec_addr(mem_rec_addr),
		.mem_rec_cacheline(mem_rec_cacheline),

		.stalled(stalled),

		.store_en(store_en),
		.store_isbyte(store_isbyte),
		.store_addr(store_addr),
		.store_data(store_data)
	);

endmodule