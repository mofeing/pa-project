`include "common.sv"
import common::*;

module memory
(
	input	logic		clk,
	input	logic		rst,

	input	logic		req_ren,
	input	pptr_t		req_raddr,

	input	logic		req_wen,
	input	pptr_t		req_waddr,
	input	cacheline_t	req_wcacheline,

	output	logic		rec_en,
	output	pptr_t		rec_addr,
	output	cacheline_t	rec_cacheline
);
	cacheline_t data [2**($bits(tag_t) + $bits(idx_t))]; // should be 1MB

	always @(posedge clk) begin
		rec_en <= 0;

		if (rst) begin
			integer file;
			word_t[3:0] buffer;

			file = $fopen("programs/buffer_sum.bin", "r");
			$fread(data, file);
			$fclose(file);

			// Reorder cachelines
			foreach (data[i]) begin
				buffer = data[i].words;
				for (int j = 0; j < 4; j++)
					data[i].words[j] = buffer[3-j];
			end

		end
		else begin
			if (req_wen) begin
				data[{req_waddr.fields.tag, req_waddr.fields.idx}] <= req_wcacheline;
			end

			if (req_ren) begin
				rec_en <= 1;
				rec_addr <= req_raddr;
				rec_cacheline <= data[{req_raddr.fields.tag, req_raddr.fields.idx}];
			end
		end
	end

endmodule