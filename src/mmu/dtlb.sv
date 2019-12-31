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

	always @(posedge clk) begin
		miss = 0;
		paddr.viface.offset = vaddr.fields.offset;

		if (rst) begin
			foreach (entry[i]) entry[i].valid = 0;
		end
		else begin
			// increase age of entries
			foreach (entry[i]) begin
				if (entry[i].valid) begin
					entry[i].age++;
				end
			end

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

			if (is_valid && flag_mem) begin
				// Translate virtual address to physical address
				if (~mode) begin
					integer j = -1;
					foreach (entry[i]) begin
						if (entry[i].valid && entry[i].vpn == vaddr.fields.vpn) begin
							j = i;
							break;
						end
					end

					// Miss if VPN not found
					if (j == -1)
						miss = 1;
					else begin
						// Rejuvenate entry if VPN found
						entry[j].age++;
						paddr.viface.ppn = entry[j].ppn;
					end
				end
				else begin
					// Disable virtual memory on supervisor mode
					paddr.serial = vaddr.serial[19:0];
				end
			end
		end
	end

endmodule