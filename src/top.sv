`include "common.sv"
`include "datapath/stage_if.sv"
`include "datapath/stage_id.sv"
`include "datapath/stage_ex.sv"
`include "datapath/stage_tl.sv"
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

	word_t rm0 [n_threads];
	word_t rm1 [n_threads];
	word_t rm2 [n_threads];
	word_t rm4 [n_threads];
	logic [n_threads-1:0] stalled;
	word_t[n_threads-1:0][32-1:0] regfile;
	logic[n_threads-1:0]	regfile_wen;
	regid_t	regfile_addr;
	word_t	regfile_data;

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
	word_t		ifid_rm4;

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
	word_t				idex_rm4;

	// EXTL interface
	// NOTE Fake 5-stage EX pipeline
	parameter REPEAT = 4;
	threadid_t 			extl_thread[REPEAT];
	logic 				extl_isvalid[REPEAT];
	logic 				extl_itlb_miss[REPEAT];
	vptr_t 				extl_pc[REPEAT];
	word_t 				extl_data[REPEAT];
	word_t 				extl_mul[REPEAT];
	word_t 				extl_r2[REPEAT];
	regid_t 			extl_dst[REPEAT];
	logic 				extl_isequal[REPEAT];
	logic 				extl_flag_mem[REPEAT];
	logic 				extl_flag_store[REPEAT];
	logic 				extl_flag_isbyte[REPEAT];
	logic 				extl_flag_mul[REPEAT];
	logic 				extl_flag_reg[REPEAT];
	logic 				extl_flag_jump[REPEAT];
	logic 				extl_flag_branch[REPEAT];
	logic 				extl_flag_iret[REPEAT];
	common::tlbwrite_t 	extl_flag_tlbwrite[REPEAT];
	word_t				extl_rm4[REPEAT];

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
	logic				tlwb_flag_store;
	logic				tlwb_flag_isbyte;

	// Scheduler - Exception Handler
	logic exc_en;
	threadid_t exc_thread;

	// Stores
	logic	store_en;
	logic	store_isbyte;
	pptr_t	store_addr;
	word_t	store_data;

	// TLB write
	logic itlb_wen;
	logic dtlb_wen;
	vpn_t tlbwrite_vpn;
	ppn_t tlbwrite_ppn;

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
		.id_rm4(ifid_rm4),

		// Scheduler
		.stalled(stalled),

		// Memory
		.mem_rec_en(ctr_icache_rec_en),
		.mem_rec_addr(ctr_icache_rec_addr),
		.mem_rec_cacheline(ctr_icache_rec_cacheline),
		.mem_req_ren(ctr_icache_req_ren),
		.mem_req_addr(ctr_icache_req_raddr),

		// TLB
		.mode({rm4[0][0], rm4[1][0], rm4[2][0], rm4[3][0], rm4[4][0], rm4[5][0], rm4[6][0], rm4[7][0]}), // NOTE initial simulation is all in supervisor mode
		.tlbwrite_en(itlb_wen),
		.tlbwrite_vpn(tlbwrite_vpn),
		.tlbwrite_ppn(tlbwrite_ppn),

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
		.if_rm4(ifid_rm4),

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
		.ex_rm4(idex_rm4),

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
		.id_rm4(idex_rm4),

		// EXTL interface
		.tl_thread(extl_thread[0]),
		.tl_isvalid(extl_isvalid[0]),
		.tl_itlb_miss(extl_itlb_miss[0]),
		.tl_pc(extl_pc[0]),
		.tl_data(extl_data[0]),
		.tl_mul(extl_mul[0]),
		.tl_r2(extl_r2[0]),
		.tl_dst(extl_dst[0]),
		.tl_isequal(extl_isequal[0]),
		.tl_flag_mem(extl_flag_mem[0]),
		.tl_flag_store(extl_flag_store[0]),
		.tl_flag_isbyte(extl_flag_isbyte[0]),
		.tl_flag_mul(extl_flag_mul[0]),
		.tl_flag_reg(extl_flag_reg[0]),
		.tl_flag_jump(extl_flag_jump[0]),
		.tl_flag_branch(extl_flag_branch[0]),
		.tl_flag_iret(extl_flag_iret[0]),
		.tl_flag_tlbwrite(extl_flag_tlbwrite[0]),
		.tl_rm4(extl_rm4[0])
	);

	always_ff @(posedge clk) begin
		for (int i = 1; i < REPEAT; i++) begin
			extl_thread[i] <= extl_thread[i-1];
			extl_isvalid[i] <= extl_isvalid[i-1];
			extl_itlb_miss[i] <= extl_itlb_miss[i-1];
			extl_pc[i] <= extl_pc[i-1];
			extl_data[i] <= extl_data[i-1];
			extl_mul[i] <= extl_mul[i-1];
			extl_r2[i] <= extl_r2[i-1];
			extl_dst[i] <= extl_dst[i-1];
			extl_isequal[i] <= extl_isequal[i-1];
			extl_flag_mem[i] <= extl_flag_mem[i-1];
			extl_flag_store[i] <= extl_flag_store[i-1];
			extl_flag_isbyte[i] <= extl_flag_isbyte[i-1];
			extl_flag_mul[i] <= extl_flag_mul[i-1];
			extl_flag_reg[i] <= extl_flag_reg[i-1];
			extl_flag_jump[i] <= extl_flag_jump[i-1];
			extl_flag_branch[i] <= extl_flag_branch[i-1];
			extl_flag_iret[i] <= extl_flag_iret[i-1];
			extl_flag_tlbwrite[i] <= extl_flag_tlbwrite[i-1];
			extl_rm4[i] <= extl_rm4[i-1];
		end
	end

	stage_tl stage_tl_inst (
		.clk(clk),
		.rst(rst),

		// EXTL connection
		.ex_thread(extl_thread[REPEAT-1]),
		.ex_isvalid(extl_isvalid[REPEAT-1]),
		.ex_itlb_miss(extl_itlb_miss[REPEAT-1]),
		.ex_pc(extl_pc[REPEAT-1]),
		.ex_data(extl_data[REPEAT-1]),
		.ex_mul(extl_mul[REPEAT-1]),
		.ex_r2(extl_r2[REPEAT-1]),
		.ex_dst(extl_dst[REPEAT-1]),
		.ex_isequal(extl_isequal[REPEAT-1]),
		.ex_flag_mem(extl_flag_mem[REPEAT-1]),
		.ex_flag_store(extl_flag_store[REPEAT-1]),
		.ex_flag_isbyte(extl_flag_isbyte[REPEAT-1]),
		.ex_flag_mul(extl_flag_mul[REPEAT-1]),
		.ex_flag_reg(extl_flag_reg[REPEAT-1]),
		.ex_flag_jump(extl_flag_jump[REPEAT-1]),
		.ex_flag_branch(extl_flag_branch[REPEAT-1]),
		.ex_flag_iret(extl_flag_iret[REPEAT-1]),
		.ex_flag_tlbwrite(extl_flag_tlbwrite[REPEAT-1]),
		.ex_rm4(extl_rm4[REPEAT-1]),

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
		.wb_flag_store(tlwb_flag_store),
		.wb_flag_isbyte(tlwb_flag_isbyte),

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

		.tlbwrite_en(dtlb_wen),
		.tlbwrite_vpn(tlbwrite_vpn),
		.tlbwrite_ppn(tlbwrite_ppn),

		.store_en(store_en),
		.store_isbyte(store_isbyte),
		.store_addr(store_addr),
		.store_data(store_data)
	);

	logic exception_state_en;
	threadid_t exception_state_master;
	logic exception_fence;
	logic exception_detected;
	vptr_t waiting_pc[n_threads];

	always_ff @(posedge clk) begin
		if (rst) begin
			for (int i = 0; i < n_threads; i++) begin
				pc[i] <= 32'h 1000;
				waiting_pc[i] <= 32'h 1000;
				rm0[i] <= 0;
				rm1[i] <= 0;
				rm2[i] <= 0;
				rm4[i] <= 1; // NOTE Fake rm4
				stalled[i] = 0;
				for (int j = 0; j < 32; j++)
					regfile[i][j] <= 0;

				// R31 stores thread id
				regfile[i][31] <= i;
			end
		end
		else begin
			store_en <= 0;
			store_addr <= tlwb_data[19:0];
			store_isbyte <= tlwb_flag_isbyte;
			store_data <= tlwb_r2;
			itlb_wen <= 0;
			dtlb_wen <= 0;
			tlbwrite_vpn <= tlwb_data[19:0];
			tlbwrite_ppn <= tlwb_r2[7:0];

			// Maintain instruction order
			exception_fence = (~exception_state_en || (exception_state_en && tlwb_thread == exception_state_master));
			exception_detected = tlwb_itlb_miss && tlwb_dtlb_miss;
			if (tlwb_pc == waiting_pc[tlwb_thread]) begin
				// Commit instruction if valid and passes the exception fence
				if (tlwb_isvalid && exception_fence) begin
					// Update PC
					pc[tlwb_thread] <= pc[tlwb_thread] + 4;
					waiting_pc[tlwb_thread] <= waiting_pc[tlwb_thread] + 4;

					// Write to register file (ALU, MUL, LD)
					if (tlwb_flag_reg)
						regfile[tlwb_thread][tlwb_dst] <= (tlwb_flag_mul) ? tlwb_mul : tlwb_data;

					// Jump/branch
					if (tlwb_flag_jump && (~tlwb_flag_branch || (tlwb_flag_branch && tlwb_isequal))) begin
						// $display("[top] jump!, sum=%d", regfile[tlwb_thread][10]);
						if (tlwb_flag_branch)
							$display("[top] branch!, sum=%d", regfile[tlwb_thread][10]);
						waiting_pc[tlwb_thread] <= tlwb_data;
						pc[tlwb_thread] <= tlwb_data;
					end

					// Store
					if (tlwb_flag_store)
						store_en <= 1;

					// TLBWRITE
					if (tlwb_flag_tlbwrite == tlbwrite_signal::itlb) itlb_wen <= 1;
					if (tlwb_flag_tlbwrite == tlbwrite_signal::dtlb) dtlb_wen <= 1;

					// IRET
					if (tlwb_flag_iret) begin
						pc[tlwb_thread] <= rm0[tlwb_thread];
						exception_state_en <= 0;
						rm4[tlwb_thread] <= 0;
					end
				end

				// Retry waiting PC if execution has not been valid or has not passed the exception fence
				else begin
					pc[tlwb_thread] <= waiting_pc[tlwb_thread];

					// Jump to exception handler if not yet in exception state
					if (~exception_state_en && exception_detected) begin
						exception_state_en <= 1;
						exception_state_master <= tlwb_thread;
						pc[tlwb_thread] <= exchandler_pc;
						waiting_pc[tlwb_thread] <= exchandler_pc;

						rm0[tlwb_thread] <= tlwb_pc;
						if (tlwb_itlb_miss) begin
							rm1[tlwb_thread] <= tlwb_pc;
							rm2[tlwb_thread] <= exception::itlb_miss;
						end else if (tlwb_dtlb_miss) begin
							rm1[tlwb_thread] <= tlwb_data;
							rm2[tlwb_thread] <= exception::dtlb_miss;
						end
						rm4[tlwb_thread] <= 1;
					end
				end
			end
		end
	end
endmodule