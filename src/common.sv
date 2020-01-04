`ifndef COMMON_H
`define COMMON_H

/* verilator lint_off DECLFILENAME */
package mux_a;
	typedef enum { regfile, pc } mux_a_t /* verilator public */;
endpackage

package mux_b;
	typedef enum { regfile, immediate } mux_b_t /* verilator public */;
endpackage

package exception;
	typedef enum {
		itlb_miss,
		dtlb_miss,
		invalid_instr,
		alu_overflow
	} exception_t /* verilator public */;
endpackage

package func;
	typedef enum logic[3:0] {
		land,
		lor,
		lnor,
		add,
		sub,
		slt
	} func_t /* verilator public */;
endpackage

package opcode;
	typedef enum logic[6:0] {
		add = 'h0,
		sub = 'h1,
		mul = 'h2,
		ldb = 'h10,
		ldw = 'h11,
		stb = 'h12,
		stw = 'h13,
		beq = 'h30,
		jump = 'h31,
		mov = 'h14,
		tlbwrite = 'h32,
		iret = 'h33,
		addi = 'h34
	} opcode_t /* verilator public */;
endpackage

package tlbwrite_signal;
	typedef enum logic[1:0] {
		off = 0,
		itlb = 1,
		dtlb = 2
	} tlbwrite_t /* verilator public */;
endpackage
/* verilator lint_on DECLFILENAME */

package common;

	import func::*;
	import opcode::*;
	import exception::*;
	import mux_a::*;
	import mux_b::*;
	import tlbwrite_signal::*;

	typedef logic [7:0] byte_t;
	typedef logic [15:0] hword_t;
	typedef logic [31:0] word_t;
	typedef logic [63:0] dword_t;
	typedef logic [4:0] regid_t;
	typedef logic [2:0] threadid_t;

	// Instruction
	typedef struct packed {
		opcode_t op;
		union packed {
			struct packed {
				regid_t dst;
				regid_t src1;
				regid_t src2;
				logic[9:0] _zero;
			} r;
			struct packed {
				regid_t dst;
				regid_t src;
				logic[14:0] immediate;
			} m;
			struct packed {
				logic[4:0] offset_hi;
				regid_t src1;
				regid_t src2;
				logic[9:0] offset_lo;
			} b;
		} fields;
	} instr_t;

	// TLB
	typedef logic [19:0] vpn_t; // Virtual Page Number
	typedef logic [11:0] page_offset_t; // Offset inside page
	typedef union packed {
		struct packed {
			vpn_t vpn;
			page_offset_t offset;
		} fields;
		logic[31:0] serial;
	} vptr_t;

	// Cache
	typedef logic [7:0] ppn_t; // Physical Page Number
	typedef logic [13:0] tag_t; // Physical Address Tag
	typedef logic [1:0] idx_t; // Cacheline index
	typedef logic [3:0] byte_offset_t; // Offset inside cacheline
	typedef union packed {
		struct packed {
			ppn_t ppn;
			page_offset_t offset;
		} viface;
		struct packed {
			tag_t tag;
			idx_t idx;
			byte_offset_t offset;
		} fields;
		logic[19:0] serial;
	} pptr_t;
	typedef union packed {
		logic[127:0] bits;
		byte_t[3:0] bytes;
		word_t[1:0] words;
	} cacheline_t;

	parameter n_threads = 8;
	parameter n_cachelines = 2**($bits(idx_t));
	parameter vptr_t[n_threads-1:0] boot_pc = {
		32'h 1000,
		32'h 1100,
		32'h 1200,
		32'h 1300,
		32'h 1400,
		32'h 1500,
		32'h 1600,
		32'h 1700
	};
	parameter vptr_t exchandler_pc = 32'h 2000;
endpackage
`endif