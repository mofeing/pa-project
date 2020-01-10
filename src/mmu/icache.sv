`include "common.sv"
import common::*;

typedef struct packed {
	logic valid;
	tag_t tag;
	cacheline_t data;
	logic waiting;
	tag_t req_tag;
	integer age;
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

module icache_setassociative
#(
	parameter integer ENTRIES_PER_SET = 2
)(
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
	icache_entry_t entry[n_cachelines][ENTRIES_PER_SET];
	icache_listener_t subscriber[n_threads];
	idx_t req_idx, rec_idx;
	tag_t req_tag, rec_tag;
	int j;

	always_comb begin
		req_idx = paddr.fields.idx;
		req_tag = paddr.fields.tag;
		rec_idx = mem_rec_addr.fields.idx;
		rec_tag = mem_rec_addr.fields.tag;

		// Miss if tag is not in the entries
		miss = 1;
		if (~itlb_miss) begin
			miss = 1;
			for (j = 0; j < ENTRIES_PER_SET; j++)
				if (entry[req_idx][j].valid && entry[req_idx][j].tag == req_tag) begin
					miss = 0;
					break;
				end
			data = entry[req_idx][j].data.words[paddr.fields.offset / 4];

			// Bypass to output if just received
			if (mem_rec_en && mem_rec_addr == {paddr.fields.tag, paddr.fields.idx, {$bits(byte_offset_t){1'b0}}}) begin
				miss = 0;
				data = mem_rec_cacheline.words[paddr.fields.offset / 4];
			end
		end

	end

	always_ff @(posedge clk) begin
		if (rst) begin
			foreach (entry[i,j]) entry[i][j].valid = 0;
			foreach (subscriber[i]) subscriber[i].valid = 0;
		end
		else begin
			// Update age of entries
			foreach (entry[i,j]) entry[i][j].age <= entry[i][j].age + 1;

			// Receive from memory
			if (mem_rec_en) begin
				logic found = 0;
				int j;

				// Find entry in "rec_idx" set
				for (j = 0; j < ENTRIES_PER_SET; j++)
					if (entry[rec_idx][j].waiting && entry[rec_idx][j].req_tag == rec_tag) begin
						found = 1;
						break;
					end

				if (found) begin
					// Save cacheline
					entry[rec_idx][j].valid <= 1;
					entry[rec_idx][j].tag <= rec_tag;
					entry[rec_idx][j].data <= mem_rec_cacheline;
					entry[rec_idx][j].waiting <= 0;
					entry[rec_idx][j].age <= 0;

					// Notify stalled threads
					// NOTE Notifies threads waiting for the same set as there are threads waiting for to load/store (and miss) in that set
					foreach (subscriber[i])
						if (subscriber[i].valid == 1 && subscriber[i].idx == rec_idx) begin
							stalled[i] <= 0;
							subscriber[i].valid <= 0;
						end
				end
			end

			// Request memory on miss
			mem_req_ren <= 0;
			if (~itlb_miss && miss) begin
				logic avail_found = 0;
				logic already_req = 0;
				int j;
				int oldest_age = 0;
				int oldest_j = 0;

				// Check that cacheline is not already requested
				for (j = 0; j < ENTRIES_PER_SET; j++)
					if (entry[req_idx][j].req_tag == req_tag) begin
						already_req = 1;
						break;
					end

				// Find oldest available entry in "req_idx" set
				// NOTE Can only request memory if there is an entry that is not waiting for memory
				for (j = 0; j < ENTRIES_PER_SET; j++)
					if (~entry[req_idx][j].waiting && entry[req_idx][j].age >= oldest_age) begin
						avail_found = 1;
						oldest_j = j;
						oldest_age = entry[req_idx][j].age;
					end

				if (~already_req && avail_found) begin
					mem_req_ren <= 1;
					mem_req_addr <= {req_tag, req_idx, {$bits(byte_offset_t){1'b0}}};

					// Set cacheline on waiting state
					entry[req_idx][oldest_j].waiting <= 1;
					entry[req_idx][oldest_j].req_tag <= req_tag;
				end

				// Stall thread
				subscriber[thread].valid <= 1;
				subscriber[thread].idx <= req_idx;
				stalled[thread] <= 1;
			end
		end
	end
endmodule