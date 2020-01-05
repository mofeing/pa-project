`include "common.sv"
`include "datapath/stage_if.sv"
`include "datapath/stage_id.sv"
`include "datapath/stage_ex.sv"
`include "datapath/stage_tl.sv"
`include "datapath/stage_wb.sv"
`include "mmu/controller.sv"
`include "mmu/memory.sv"
`include "mmu/bus.sv"
`include "regfile.sv"
import common::*;

module top
(
	input	wire 	clk,
	input	wire	rst
);
	// Thread state
	vptr_t pc [n_threads];
	logic[n_threads-1:0] wb_pc_en;
	vptr_t wb_pc_data;

	word_t rm0 [n_threads];
	word_t rm1 [n_threads];
	word_t rm2 [n_threads];
	word_t rm4 [n_threads];
	logic [n_threads-1:0] stalled;
	word_t[n_threads-1:0][32-1:0] regfile;
	logic[n_threads-1:0]	regfile_wen;
	regid_t	regfile_addr;
	word_t	regfile_data;

	// NOTE initial simulation is all in supervisor mode
	word_t fake_rm4[n_threads];
	always_comb
		for (int i = 0; i < n_threads; i++)
			fake_rm4[i] = 1;

	// Memory
	/// i-cache <-> controller
	logic		ctr_icache_req_ren;
	pptr_t		ctr_icache_req_raddr;
	logic		ctr_icache_rec_en;
	pptr_t		ctr_icache_rec_addr;
	cacheline_t	ctr_icache_rec_cacheline;

	/// dcache <-> controller
	logic		ctr_dcache_req_ren;
	pptr_t		ctr_dcache_req_raddr;
	logic		ctr_dcache_req_wen;
	pptr_t		ctr_dcache_req_waddr;
	cacheline_t	ctr_dcache_req_wcacheline;
	logic		ctr_dcache_rec_en;
	pptr_t		ctr_dcache_rec_addr;
	cacheline_t ctr_dcache_rec_cacheline;

	/// controller <-> bus
	logic		ctr_bus_req_ren;
	pptr_t		ctr_bus_req_raddr;
	logic		ctr_bus_req_wen;
	pptr_t		ctr_bus_req_waddr;
	cacheline_t	ctr_bus_req_wcacheline;
	logic		ctr_bus_rec_en;
	pptr_t		ctr_bus_rec_addr;
	cacheline_t	ctr_bus_rec_cacheline;

	/// memory <-> bus
	logic		mem_bus_req_ren;
	pptr_t		mem_bus_req_raddr;
	logic		mem_bus_req_wen;
	pptr_t		mem_bus_req_waddr;
	cacheline_t	mem_bus_req_wcacheline;
	logic		mem_bus_rec_en;
	pptr_t		mem_bus_rec_addr;
	cacheline_t	mem_bus_rec_cacheline;

	controller controller_inst(
		.clk(clk),
		.rst(rst),

		/* i-cache */
		.icache_req_ren(ctr_icache_req_ren),
		.icache_req_raddr(ctr_icache_req_raddr),
		.icache_rec_en(ctr_icache_rec_en),
		.icache_rec_addr(ctr_icache_rec_addr),
		.icache_rec_cacheline(ctr_icache_rec_cacheline),

		/* d-cache */
		.dcache_req_ren(ctr_dcache_req_ren),
		.dcache_req_raddr(ctr_dcache_req_raddr),
		.dcache_req_wen(ctr_dcache_req_wen),
		.dcache_req_waddr(ctr_dcache_req_waddr),
		.dcache_req_wcacheline(ctr_dcache_req_wcacheline),
		.dcache_rec_en(ctr_dcache_rec_en),
		.dcache_rec_addr(ctr_dcache_rec_addr),
		.dcache_rec_cacheline(ctr_dcache_rec_cacheline),

		/* mem */
		.mem_req_ren(ctr_bus_req_ren),
		.mem_req_raddr(ctr_bus_req_raddr),
		.mem_req_wen(ctr_bus_req_wen),
		.mem_req_waddr(ctr_bus_req_waddr),
		.mem_req_wcacheline(ctr_bus_req_wcacheline),
		.mem_rec_en(ctr_bus_rec_en),
		.mem_rec_addr(ctr_bus_rec_addr),
		.mem_rec_cacheline(ctr_bus_rec_cacheline)
	);

	bus bus_inst(
		.clk(clk),

		// memory
		.mem_req_ren(mem_bus_req_ren),
		.mem_req_raddr(mem_bus_req_raddr),
		.mem_req_wen(mem_bus_req_wen),
		.mem_req_waddr(mem_bus_req_waddr),
		.mem_req_wcacheline(mem_bus_req_wcacheline),
		.mem_rec_en(mem_bus_rec_en),
		.mem_rec_addr(mem_bus_rec_addr),
		.mem_rec_cacheline(mem_bus_rec_cacheline),

		// controller
		.ctr_req_ren(ctr_bus_req_ren),
		.ctr_req_raddr(ctr_bus_req_raddr),
		.ctr_req_wen(ctr_bus_req_wen),
		.ctr_req_waddr(ctr_bus_req_waddr),
		.ctr_req_wcacheline(ctr_bus_req_wcacheline),
		.ctr_rec_en(ctr_bus_rec_en),
		.ctr_rec_addr(ctr_bus_rec_addr),
		.ctr_rec_cacheline(ctr_bus_rec_cacheline)
	);

	memory memory_inst(
		.clk(clk),
		.rst(rst),
		.req_ren(mem_bus_req_ren),
		.req_raddr(mem_bus_req_raddr),
		.req_wen(mem_bus_req_wen),
		.req_waddr(mem_bus_req_waddr),
		.req_wcacheline(mem_bus_req_wcacheline),
		.rec_en(mem_bus_rec_en),
		.rec_addr(mem_bus_rec_addr),
		.rec_cacheline(mem_bus_rec_cacheline)
	);

	// Interfaces
	/// IFID interface
	logic		ifid_itlb_miss;
	logic		ifid_icache_miss;
	vptr_t		ifid_pc;
	word_t		ifid_instruction;
	threadid_t	ifid_thread;

	/// IDEX interface
	threadid_t			idex_thread;
	logic				idex_itlb_miss;
	logic				idex_isvalid;
	regid_t				idex_dst;
	vptr_t				idex_pc;
	word_t				idex_r1;
	common::mux_a_t		idex_a;
	word_t				idex_r2;
	word_t				idex_imm;
	common::mux_b_t		idex_b;
	common::func_t		idex_alu_func;
	logic				idex_flag_mem;
	logic				idex_flag_store;
	logic				idex_flag_isbyte;
	logic				idex_flag_mul;
	logic				idex_flag_reg;
	logic				idex_flag_jump;
	logic				idex_flag_branch;
	logic				idex_flag_iret;
	common::tlbwrite_t	idex_flag_tlbwrite;

	// EXTL interface
	threadid_t 			extl_thread;
	logic 				extl_isvalid;
	logic 				extl_itlb_miss;
	vptr_t 				extl_pc;
	word_t 				extl_data;
	word_t 				extl_mul;
	word_t 				extl_r2;
	regid_t 			extl_dst;
	logic 				extl_isequal;
	logic 				extl_flag_mem;
	logic 				extl_flag_store;
	logic 				extl_flag_isbyte;
	logic 				extl_flag_mul;
	logic 				extl_flag_reg;
	logic 				extl_flag_jump;
	logic 				extl_flag_branch;
	logic 				extl_flag_iret;
	common::tlbwrite_t 	extl_flag_tlbwrite;

	// TLWB interface
	threadid_t			tlwb_thread;
	logic				tlwb_isvalid;
	logic				tlwb_itlb_miss;
	logic				tlwb_dtlb_miss;
	regid_t				tlwb_dst;
	vptr_t				tlwb_pc;
	word_t				tlwb_r2;
	word_t				tlwb_data;
	logic				tlwb_isequal;
	word_t				tlwb_mul;
	logic 				tlwb_flag_mul;
	logic 				tlwb_flag_reg;
	logic 				tlwb_flag_jump;
	logic 				tlwb_flag_branch;
	logic 				tlwb_flag_iret;
	common::tlbwrite_t	tlwb_flag_tlbwrite;

	// Scheduler - Exception Handler
	logic exc_en;
	threadid_t exc_thread;

	// Stores
	logic	store_en;
	logic	store_isbyte;
	pptr_t	store_addr;
	word_t	store_data;


	// Stages
	stage_if stage_if_inst(
		.clk(clk),
		.rst(rst),

		// IFID connection
		.id_itlb_miss(ifid_itlb_miss),
		.id_icache_miss(ifid_icache_miss),
		.id_pc(ifid_pc),
		.id_instruction(ifid_instruction),
		.id_thread(ifid_thread),

		// Scheduler
		.stalled(stalled),

		// Memory
		.mem_rec_en(ctr_icache_rec_en),
		.mem_rec_addr(ctr_icache_rec_addr),
		.mem_rec_cacheline(ctr_icache_rec_cacheline),
		.mem_req_ren(ctr_icache_req_ren),
		.mem_req_addr(ctr_icache_req_raddr),

		// TLB
		.mode({fake_rm4[0][0], fake_rm4[1][0], fake_rm4[2][0], fake_rm4[3][0], fake_rm4[4][0], fake_rm4[5][0], fake_rm4[6][0], fake_rm4[7][0]}), // NOTE initial simulation is all in supervisor mode
		.tlbwrite_en(0), // NOTE initial simulation is all in supervisor mode
		.tlbwrite_vpn(), // NOTE initial simulation is all in supervisor mode
		.tlbwrite_ppn(), // NOTE initial simulation is all in supervisor mode

		// PC of threads (speculative increment of a word outside this module)
		.pc({pc[0], pc[1], pc[2], pc[3], pc[4], pc[5], pc[6], pc[7]}),

		// Exception handler
		.exc_en(exc_en),
		.exc_thread(exc_thread)
	);

	stage_id stage_id_inst (
		.clk(clk),
		.rst(rst),

		// IF connection
		.if_itlb_miss(ifid_itlb_miss),
		.if_icache_miss(ifid_icache_miss),
		.if_pc(ifid_pc),
		.if_instruction(ifid_instruction),
		.if_thread(ifid_thread),

		// EX connection
		.ex_thread(idex_thread),
		.ex_itlb_miss(idex_itlb_miss),
		.ex_isvalid(idex_isvalid),
		.ex_dst(idex_dst),
		.ex_pc(idex_pc),
		.ex_r1(idex_r1),
		.ex_a(idex_a),
		.ex_r2(idex_r2),
		.ex_imm(idex_imm),
		.ex_b(idex_b),
		.ex_alu_func(idex_alu_func),
		.ex_flag_mem(idex_flag_mem),
		.ex_flag_store(idex_flag_store),
		.ex_flag_isbyte(idex_flag_isbyte),
		.ex_flag_mul(idex_flag_mul),
		.ex_flag_reg(idex_flag_reg),
		.ex_flag_jump(idex_flag_jump),
		.ex_flag_branch(idex_flag_branch),
		.ex_flag_iret(idex_flag_iret),
		.ex_flag_tlbwrite(idex_flag_tlbwrite),

		// Register file
		.regfile(regfile)
	);

	stage_ex stage_ex_inst (
		.clk(clk),
		.rst(rst),

		// IDEX interface
		.id_thread(idex_thread),
		.id_itlb_miss(idex_itlb_miss),
		.id_isvalid(idex_isvalid),
		.id_dst(idex_dst),
		.id_pc(idex_pc),
		.id_r1(idex_r1),
		.id_a(idex_a),
		.id_r2(idex_r2),
		.id_imm(idex_imm),
		.id_b(idex_b),
		.id_alu_func(idex_alu_func),
		.id_flag_mem(idex_flag_mem),
		.id_flag_store(idex_flag_store),
		.id_flag_isbyte(idex_flag_isbyte),
		.id_flag_mul(idex_flag_mul),
		.id_flag_reg(idex_flag_reg),
		.id_flag_jump(idex_flag_jump),
		.id_flag_branch(idex_flag_branch),
		.id_flag_iret(idex_flag_iret),
		.id_flag_tlbwrite(idex_flag_tlbwrite),

		// EXTL interface
		.tl_thread(extl_thread),
		.tl_isvalid(extl_isvalid),
		.tl_itlb_miss(extl_itlb_miss),
		.tl_pc(extl_pc),
		.tl_data(extl_data),
		.tl_mul(extl_mul),
		.tl_r2(extl_r2),
		.tl_dst(extl_dst),
		.tl_isequal(extl_isequal),
		.tl_flag_mem(extl_flag_mem),
		.tl_flag_store(extl_flag_store),
		.tl_flag_isbyte(extl_flag_isbyte),
		.tl_flag_mul(extl_flag_mul),
		.tl_flag_reg(extl_flag_reg),
		.tl_flag_jump(extl_flag_jump),
		.tl_flag_branch(extl_flag_branch),
		.tl_flag_iret(extl_flag_iret),
		.tl_flag_tlbwrite(extl_flag_tlbwrite)
	);

	stage_tl stage_tl_inst (
		.clk(clk),
		.rst(rst),

		// EXTL connection
		.ex_thread(extl_thread),
		.ex_isvalid(extl_isvalid),
		.ex_itlb_miss(extl_itlb_miss),
		.ex_pc(extl_pc),
		.ex_data(extl_data),
		.ex_mul(extl_mul),
		.ex_r2(extl_r2),
		.ex_dst(extl_dst),
		.ex_isequal(extl_isequal),
		.ex_flag_mem(extl_flag_mem),
		.ex_flag_store(extl_flag_store),
		.ex_flag_isbyte(extl_flag_isbyte),
		.ex_flag_mul(extl_flag_mul),
		.ex_flag_reg(extl_flag_reg),
		.ex_flag_jump(extl_flag_jump),
		.ex_flag_branch(extl_flag_branch),
		.ex_flag_iret(extl_flag_iret),
		.ex_flag_tlbwrite(extl_flag_tlbwrite),

		// TLWB connection
		.wb_thread(tlwb_thread),
		.wb_isvalid(tlwb_isvalid),
		.wb_itlb_miss(tlwb_itlb_miss),
		.wb_dtlb_miss(tlwb_dtlb_miss),
		.wb_dst(tlwb_dst),
		.wb_pc(tlwb_pc),
		.wb_r2(tlwb_r2),
		.wb_data(tlwb_data),
		.wb_isequal(tlwb_isequal),
		.wb_mul(tlwb_mul),
		.wb_flag_mul(tlwb_flag_mul),
		.wb_flag_reg(tlwb_flag_reg),
		.wb_flag_jump(tlwb_flag_jump),
		.wb_flag_branch(tlwb_flag_branch),
		.wb_flag_iret(tlwb_flag_iret),
		.wb_flag_tlbwrite(tlwb_flag_tlbwrite),

		.stalled(stalled),

		// Memory connection
		.mem_req_ren(ctr_dcache_req_ren),
		.mem_req_raddr(ctr_dcache_req_raddr),
		.mem_req_wen(ctr_dcache_req_wen),
		.mem_req_waddr(ctr_dcache_req_waddr),
		.mem_req_wcacheline(ctr_dcache_req_wcacheline),
		.mem_rec_en(ctr_dcache_rec_en),
		.mem_rec_addr(ctr_dcache_rec_addr),
		.mem_rec_cacheline(ctr_dcache_rec_cacheline),

		// .write_en(write_en),
		// .write_vpn(write_vpn),
		// .write_ppn(write_ppn),
		// .mode(mode),

		.store_en(store_en),
		.store_isbyte(store_isbyte),
		.store_addr(store_addr),
		.store_data(store_data)
	);

	stage_wb stage_wb_inst (
		.clk(clk),
		.rst(rst),

		// TLWB connection
		.tl_thread(tlwb_thread),
		.tl_isvalid(tlwb_isvalid),
		.tl_itlb_miss(tlwb_itlb_miss),
		.tl_dtlb_miss(tlwb_dtlb_miss),
		.tl_dst(tlwb_dst),
		.tl_pc(tlwb_pc),
		.tl_r2(tlwb_r2),
		.tl_data(tlwb_data),
		.tl_isequal(tlwb_isequal),
		.tl_mul(tlwb_mul),
		.tl_flag_mul(tlwb_flag_mul),
		.tl_flag_reg(tlwb_flag_reg),
		.tl_flag_jump(tlwb_flag_jump),
		.tl_flag_branch(tlwb_flag_branch),
		.tl_flag_iret(tlwb_flag_iret),
		.tl_flag_tlbwrite(tlwb_flag_tlbwrite),

		// Special registers and PC
		// .pc(pc),
		.pc_en(wb_pc_en),
		.pc_data(wb_pc_data),
		// .rm0(rm0),
		// .rm1(rm1),
		// .rm2(rm2),
		// .rm4(rm4),

		// Register file
		.regfile_wen(regfile_wen),
		.regfile_addr(regfile_addr),
		.regfile_data(regfile_data),

		// TLB
		// .itlb_wen(itlb_wen),
		// .itlb_vpn(itlb_vpn),
		// .itlb_ppn(itlb_ppn),
		// .dtlb_wen(dtlb_wen),
		// .dtlb_vpn(dtlb_vpn),
		// .dtlb_ppn(dtlb_ppn),

		// Scheduler
		.exc_en(exc_en),
		.exc_thread(exc_thread)
	);

	always_ff @(posedge clk) begin
	 	if (rst) begin
			for (int i = 0; i < n_threads; i++) begin
				pc[i] <= 32'h 1000;
				rm0[i] <= 0;
				rm1[i] <= 0;
				rm2[i] <= 0;
				rm4[i] <= 0;
				stalled[i] = 0;
				for (int j = 0; j < 32; j++)
					regfile[i][j] <= 0;

				// R31 stores thread id
				regfile[i][31] <= i;
			end
		end
		else begin
			for (int i = 0; i < n_threads; i++) begin
				if (regfile_wen[i] == 1)
					regfile[i][regfile_addr] <= regfile_data;

				// if (wb_pc_en[i] == 1)
				// 	pc[i] <= wb_pc_data + 4;
				// else if (ifid_thread == i[2:0])
				// 	pc[i] <= pc[i] + 4;
			end
		end
	end
endmodule