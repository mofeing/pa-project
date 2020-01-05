`include "common.sv"
import common::*;

typedef struct packed {
	logic valid;
	tag_t tag;
	cacheline_t data;
	logic waiting;
	tag_t req_tag;
} icache_entry_t;

typedef struct packed {
	logic valid;
	idx_t idx;
} icache_listener_t;

module icache_directmap
(
	input	logic					clk,
	input	logic					rst,

	input	threadid_t				thread,

	input	pptr_t					paddr,
	input	logic					itlb_miss,

	output	logic					miss,
	output	word_t					data,

	// Memory
	input	logic					mem_rec_en,
	input	pptr_t					mem_rec_addr,
	input	cacheline_t				mem_rec_cacheline,
	output	logic					mem_req_ren,
	output	pptr_t					mem_req_addr,

	// Stalled bits
	output logic[n_threads-1:0]		stalled
);
	icache_entry_t entry[n_cachelines];
	icache_listener_t listener[n_threads];
	idx_t req_idx;
	tag_t req_tag;
	byte_offset_t offset;

	always_comb begin
		req_idx = paddr.fields.idx;
		req_tag = paddr.fields.tag;
		offset = paddr.fields.offset / 4; // NOTE we are reading words

		// Miss if tag is not in the entries
		miss = ~(entry[req_idx].valid && entry[req_idx].tag == req_tag);
		data = entry[req_idx].data.words[offset];

		// Bypass to output if just received
		if (mem_rec_en && mem_rec_addr == {paddr.fields.tag, paddr.fields.idx, {$bits(byte_offset_t){1'b0}}}) begin
			miss = 0;
			data = mem_rec_cacheline.words[offset];
		end
	end

	always_ff @(posedge clk) begin
		if (rst) begin
			foreach (entry[i]) entry[i].valid = 0;
			foreach (listener[i]) listener[i].valid = 0;
		end
		else begin
			// Receive from memory
			idx_t rec_idx = mem_rec_addr.fields.idx;
			tag_t rec_tag = mem_rec_addr.fields.tag;
			if (mem_rec_en && entry[rec_idx].req_tag == rec_tag) begin
				// Save cacheline
				entry[rec_idx].valid <= 1;
				entry[rec_idx].tag <= rec_tag;
				entry[rec_idx].data <= mem_rec_cacheline;
				entry[rec_idx].waiting <= 0;

				// Notify stalled threads
				foreach (listener[i])
					if (listener[i].valid == 1 && listener[i].idx == rec_idx) begin
						stalled[i] <= 0;
						listener[i].valid <= 0;
					end
			end

			mem_req_ren <= 0;
			if (~itlb_miss && miss) begin
				if (~entry[req_idx].waiting) begin
					// Request cacheline to memory
					mem_req_ren <= 1;
					mem_req_addr <= {paddr.fields.tag, paddr.fields.idx, {$bits(byte_offset_t){1'b0}}};

					// Stall thread
					listener[thread].valid <= 1;
					listener[thread].idx <= req_idx;
					stalled[thread] <= 1;

					// Set cacheline on waiting state
					entry[req_idx].waiting <= 1;
					entry[req_idx].req_tag <= req_tag;
				end
				else if (entry[req_idx].req_tag == req_tag) begin
					// Stall thread
					listener[thread].valid <= 1;
					listener[thread].idx <= req_idx;
					stalled[thread] <= 1;
				end
			end
		end
	end
endmodule