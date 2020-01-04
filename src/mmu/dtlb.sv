`include "common.sv"
import common::*;

typedef struct packed {
	logic valid;
	vpn_t vpn;
	ppn_t ppn;
	integer age;
} dtlb_entry_t;

module dtlb
#(
	parameter N = 16
)
(
	input			clk,
	input			rst,

	input	logic	mode,
	input	vptr_t	vaddr,
	output	pptr_t	paddr,

	output	logic	miss,

	input	logic	write_en,
	input	vpn_t	write_vpn,
	input	ppn_t	write_ppn,

	input	logic	is_valid,
	input	logic	flag_mem
);
	dtlb_entry_t entry [N];
	integer lookfor; // TODO Review if lookfor procedure again inside always_ff

	always_comb begin
		miss = 0;
		paddr.viface.offset = vaddr.fields.offset;

		if (flag_mem && is_valid) begin
			// Supervisor mode
			if (mode)
				paddr.viface.ppn = vaddr.fields.vpn[7:0];

			// User mode
			else begin
				// Search for virtual page table in entries
				miss = 1;
				lookfor = 0;
				foreach (entry[i]) begin
					if (entry[i].valid && entry[i].vpn == vaddr.fields.vpn) begin
						lookfor = i;
						miss = 0;
						break;
					end
				end

				paddr.viface.ppn = entry[lookfor].ppn;
			end
		end
	end

	always_ff @(posedge clk) begin
		if (rst)
			foreach (entry[i]) entry[i].valid = 0;
		else begin
			// Increase age of entries
			foreach (entry[i])
				if (entry[i].valid)
					entry[i].age++;

			// Update entry on write_en
			if (write_en) begin
				// Select first empty entry or oldest non-accesed
				integer j = 0;
				integer max = 0;
				foreach (entry[i]) begin
					if (~entry[i].valid) begin
						j = i;
						break;
					end
					if (entry[i].age > max) begin
						j = i;
						max = entry[i].age;
					end
				end

				entry[j].valid <= 1;
				entry[j].vpn <= write_vpn;
				entry[j].ppn <= write_ppn;
				entry[j].age <= 0;
			end

			// Rejuvenate entry if VPN found
			if (flag_mem && is_valid && ~miss)
				entry[lookfor].age <= 0;
		end
	end
endmodule