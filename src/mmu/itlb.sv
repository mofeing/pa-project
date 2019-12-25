`include "common.sv"
import common::*;

typedef struct packed {
	logic valid;
	vpn_t vpn;
	ppn_t ppn;
	integer age;
} itlb_entry_t;

module itlb
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
	input	ppn_t	write_ppn
);
	itlb_entry_t entry [N];

	always_ff @(posedge clk) begin
		miss = 0;
		paddr.viface.offset = vaddr.fields.offset;

		if (rst) begin
			foreach (entry[i]) entry[i].valid = 0;
		end
		else begin
			// Update entry on write_enable
			if (write_en) begin
				// Select first empty entry or oldest non-accesed
				integer j = -1;
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
					entry[j].age <= 0;
					paddr.viface.ppn = entry[j].ppn;
				end
			end
			// Disable virtual memory on supervisor mode
			else begin
				paddr.serial = vaddr.serial[19:0];
			end
		end
	end

endmodule