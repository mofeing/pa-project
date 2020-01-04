`include "common.sv"
import common::*;

typedef struct packed {
	logic valid;
	tag_t tag;
	cacheline_t data;
	logic waiting;
	tag_t req_tag;
	logic dirty;
} dcache_entry_t;

typedef struct packed {
	logic valid;
	idx_t idx;
} dcache_listener_t;

module dcache_directmap
(
	input	logic					clk,
	input	logic					rst,

	input	threadid_t				thread,

	input	pptr_t					paddr,
	input	logic					isvalid,

	output	logic					miss,
	output	word_t					data,

	// Flags
	input	logic					dtlb_miss,
	input	logic					flag_mem,
	input	logic					flag_store,
	input	logic					flag_isbyte,

	// Memory
	output	logic					mem_req_ren,
	output	pptr_t					mem_req_raddr,
	output	logic					mem_req_wen,
	output	pptr_t					mem_req_waddr,
	output	cacheline_t				mem_req_wcacheline,
	input	logic					mem_rec_en,
	input	pptr_t					mem_rec_addr,
	input	cacheline_t 			mem_rec_cacheline,

	// Stalled bits
	output logic[n_threads-1:0]		stalled,

	// Store
	// uses 'miss' to communicate to committer if store is ok
	input	logic					store_en,
	input	logic					store_isbyte,
	input	pptr_t					store_addr,
	input	word_t					store_data
);
	dcache_entry_t entry[n_cachelines];
	dcache_listener_t listener[n_threads];
	idx_t req_idx, rec_idx;
	tag_t req_tag, rec_tag;

	always_comb begin
		req_idx = paddr.fields.idx;
		req_tag = paddr.fields.tag;
		rec_idx = mem_rec_addr.fields.idx;
		rec_tag = mem_rec_addr.fields.tag;

		miss = ~(entry[req_idx].valid && entry[req_idx].tag == req_tag) || dtlb_miss;
		data = entry[req_idx].data.words[paddr.fields.offset];
	end

	always_ff @(posedge clk) begin
		if (rst) begin
			foreach (entry[i]) entry[i].valid = 0;
			foreach (listener[i]) listener[i].valid = 0;
		end
		else begin
			// Commit store to cacheline after passing the committer
			if (store_en) begin
				idx_t st_idx = store_addr.fields.idx;
				byte_offset_t st_byte_offset = store_addr.fields.offset;

				// Mark entry as dirty
				entry[st_idx].dirty = 1;

				if (store_isbyte)
					entry[st_idx].data.bytes[st_byte_offset] = store_data[7:0];
				else
					entry[st_idx].data.words[st_byte_offset[3:2]] = store_data;
			end

			// Receive from memory
			if (mem_rec_en && entry[rec_idx].req_tag == rec_tag) begin
				// Commit cacheline to memory if dirty
				if (entry[rec_idx].valid && entry[rec_idx].dirty) begin
					mem_req_wen <= 1;
					mem_req_waddr <= {entry[rec_idx].tag, rec_idx, {$bits(byte_offset_t){1'b0}}};
					mem_req_wcacheline <= entry[rec_idx].data;
				end

				// Save cacheline
				entry[rec_idx].valid = 1;
				entry[rec_idx].tag = rec_tag;
				entry[rec_idx].data = mem_rec_cacheline;
				entry[rec_idx].waiting = 0;
				entry[rec_idx].dirty = 0;

				// Notify stalled threads
				foreach (listener[i])
					if (listener[i].valid == 1 && listener[i].idx == rec_idx) begin
						stalled[i] <= 0;
						listener[i].valid <= 0;
					end
			end

			// Request memory on miss
			mem_req_ren <= 0;
			if (flag_mem && isvalid && ~dtlb_miss && miss) begin
				// NOTE Can only request memory if entry is not waiting for memory
				if (~entry[req_idx].waiting) begin
					mem_req_ren <= 1;
					mem_req_raddr <= {req_tag, req_idx, {$bits(byte_offset_t){1'b0}}};

					// Set cacheline on waiting state
					entry[req_idx].waiting = 1;
					entry[req_idx].req_tag = req_tag;
				end

				// Stall thread
				listener[thread].valid <= 1;
				listener[thread].idx <= req_idx;
				stalled[thread] <= 1;
			end
		end
	end
endmodule