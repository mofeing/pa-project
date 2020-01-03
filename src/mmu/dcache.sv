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

	output	logic					miss,
	output	word_t					data,

	// Flags
	input	logic					dtlb_miss,
	input	logic					flag_mem,
	input	logic					flag_store,
	input	logic					flag_isbyte,

	// Memory
	output	logic					mem_req_ren,
	output	pptr_t					mem_req_raddr, // TODO change in memory module
	output	logic					mem_req_wen,
	output	pptr_t					mem_req_waddr, // TODO change in memory module
	output	cacheline_t				mem_req_wcacheline,
	input	logic					mem_rec_en,
	input	pptr_t					mem_rec_addr, // TODO change in memory module
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

	always_ff @(posedge clk) begin
		// Defaults
		miss <= 0;
		mem_req_ren <= 0;
		mem_req_wen <= 0;

		if (rst) begin : reset
			foreach (entry[i]) entry[i].valid = 0;
			foreach (listener[i]) listener[i].valid = 0;
		end
		else begin : active
			// Receive from memory
			idx_t rec_idx = mem_rec_addr.fields.idx;
			tag_t rec_tag = mem_rec_addr.fields.tag;
			if (mem_rec_en && entry[rec_idx].req_tag == rec_tag) begin : mem_receive
				// Save cacheline
				entry[rec_idx].valid = 1;
				entry[rec_idx].tag = entry[rec_idx].req_tag;
				entry[rec_idx].data = mem_rec_cacheline;
				entry[rec_idx].waiting = 0;
				entry[rec_idx].dirty = 0;

				// Notify stalled threads
				foreach (listener[i])
					if (listener[i].valid == 1 && listener[i].idx == rec_idx) begin
						stalled[i] <= 0;
						listener[i].valid = 0;
					end
			end

			// Commit store after passing the committer
			if (store_en) begin : store_receive
				idx_t st_idx = store_addr.fields.idx;
				byte_offset_t st_byte_offset = store_addr.fields.offset;

				// Mark entry as dirty
				entry[st_idx].dirty = 1;

				if (store_isbyte) begin
					entry[st_idx].data.bytes[st_byte_offset] = store_data[7:0];
				end
				else begin
					entry[st_idx].data.words[st_byte_offset[3:2]] = store_data;
				end
			end

			// Proceed if no D-TLB miss
			if (flag_mem && ~dtlb_miss) begin : proceed
				idx_t req_idx = paddr.fields.idx;
				tag_t req_tag = paddr.fields.tag;

				if (~flag_store) begin // load
					// Read on hit
					if (entry[req_idx].valid && entry[req_idx].tag == req_tag) begin
						data <= (flag_isbyte)
							? {24'b0, entry[req_idx].data.bytes[paddr.fields.offset]}
							: entry[req_idx].data.words[paddr.fields.offset[3:2]];
					end
					else
						miss <= 1;
				end
				else begin // store
					// Design artifact: cannot do store if cacheline can be replaced on the next cycle
					if (~entry[req_idx].valid || entry[req_idx].tag != req_tag || entry[req_idx].waiting)
						miss <= 1;
				end

				// Request cacheline to memory if miss and entry is not waiting other cacheline
				if (miss && (~entry[req_idx].waiting || ~entry[req_idx].valid)) begin : mem_request
					// Request cacheline to memory
					mem_req_ren <= 1;
					mem_req_raddr <= paddr;

					// Flush cacheline to memory if dirty
					if (entry[req_idx].valid && entry[req_idx].dirty) begin
						mem_req_wen <= 1;
						mem_req_waddr <= {entry[req_idx].tag, req_idx, 4'b0};
						mem_req_wcacheline <= entry[req_idx].data;
					end

					// Stall thread
					listener[thread].valid <= 1;
					listener[thread].idx <= req_idx;
					stalled[thread] <= 1;

					// Set cacheline on waiting state
					entry[req_idx].waiting <= 1;
					entry[req_idx].req_tag <= req_tag;
				end
			end
		end
	end

endmodule