`include "common.sv"
import common::*;

module bus
#(
	parameter D = 5
)(
	input	clk,

	// memory
	output logic		mem_req_ren,
	output pptr_t		mem_req_raddr,
	output logic		mem_req_wen,
	output pptr_t		mem_req_waddr,
	output cacheline_t	mem_req_wcacheline,
	input logic			mem_rec_en,
	input pptr_t		mem_rec_addr,
	input cacheline_t	mem_rec_cacheline,

	// controller
	input logic			ctr_req_ren,
	input pptr_t		ctr_req_raddr,
	input logic			ctr_req_wen,
	input pptr_t		ctr_req_waddr,
	input cacheline_t	ctr_req_wcacheline,
	output logic		ctr_rec_en,
	output pptr_t		ctr_rec_addr,
	output cacheline_t	ctr_rec_cacheline
);
	logic		buffer_req_ren[D];
	pptr_t		buffer_req_raddr[D];
	logic		buffer_req_wen[D];
	pptr_t		buffer_req_waddr[D];
	cacheline_t	buffer_req_wcacheline[D];
	logic		buffer_rec_en[D];
	pptr_t		buffer_rec_addr[D];
	cacheline_t	buffer_rec_cacheline[D];

	always_comb begin
		// Push to buffers
		buffer_rec_en[D-1] = mem_rec_en;
		buffer_rec_addr[D-1] = mem_rec_addr;
		buffer_rec_cacheline[D-1] = mem_rec_cacheline;
		buffer_req_ren[D-1] = ctr_req_ren;
		buffer_req_raddr[D-1] = ctr_req_raddr;
		buffer_req_wen[D-1] = ctr_req_wen;
		buffer_req_waddr[D-1] = ctr_req_waddr;
		buffer_req_wcacheline[D-1] = ctr_req_wcacheline;

		// Pop from buffers
		mem_req_ren = buffer_req_ren[0];
		mem_req_raddr = buffer_req_raddr[0];
		mem_req_wen = buffer_req_wen[0];
		mem_req_waddr = buffer_req_waddr[0];
		mem_req_wcacheline = buffer_req_wcacheline[0];
		ctr_rec_en = buffer_rec_en[0];
		ctr_rec_addr = buffer_rec_addr[0];
		ctr_rec_cacheline = buffer_rec_cacheline[0];
	end

	always_ff @(posedge clk) begin
		for (int i = 0; i < D-1; i++) begin
			buffer_req_ren[i] <= buffer_req_ren[i+1];
			buffer_req_raddr[i] <= buffer_req_raddr[i+1];
			buffer_req_wen[i] <= buffer_req_wen[i+1];
			buffer_req_waddr[i] <= buffer_req_waddr[i+1];
			buffer_req_wcacheline[i] <= buffer_req_wcacheline[i+1];
			buffer_rec_en[i] <= buffer_rec_en[i+1];
			buffer_rec_addr[i] <= buffer_rec_addr[i+1];
			buffer_rec_cacheline[i] <= buffer_rec_cacheline[i+1];
		end
	end

endmodule