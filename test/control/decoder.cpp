#include <verilated_vcd_c.h>
#include <verilated.h>
#include "Vdecoder.h"
#include "Vcommon_func.h"
#include "Vcommon_mux_a.h"
#include "Vcommon_mux_b.h"
#include "Vcommon_opcode.h"
#include "Vcommon.h"
#include <memory>
#include <iostream>

int main(int argc, char const *argv[])
{
	Verilated::commandArgs(argc, argv);

	// Instantiate module
	std::unique_ptr<Vdecoder> mod(new Vdecoder);

	// Activate waveform tracing
	Verilated::traceEverOn(true);
	std::unique_ptr<VerilatedVcdC> tracer(new VerilatedVcdC);
	mod->trace(tracer.get(), 0);
	tracer->open("decoder.vcd");

	// Tests
	vluint64_t time = 0;

	mod->instruction = Vcommon_opcode::add << 25;
	mod->eval();
	tracer->dump(time++);

	mod->instruction = Vcommon_opcode::sub << 25;
	mod->eval();
	tracer->dump(time++);

	mod->instruction = Vcommon_opcode::mul << 25;
	mod->eval();
	tracer->dump(time++);

	mod->instruction = Vcommon_opcode::ldb << 25;
	mod->eval();
	tracer->dump(time++);

	mod->instruction = Vcommon_opcode::ldw << 25;
	mod->eval();
	tracer->dump(time++);

	mod->instruction = Vcommon_opcode::stb << 25;
	mod->eval();
	tracer->dump(time++);

	mod->instruction = Vcommon_opcode::stw << 25;
	mod->eval();
	tracer->dump(time++);

	mod->instruction = Vcommon_opcode::beq << 25;
	mod->eval();
	tracer->dump(time++);

	mod->instruction = Vcommon_opcode::jump << 25;
	mod->eval();
	tracer->dump(time++);

	mod->instruction = Vcommon_opcode::mov << 25;
	mod->eval();
	tracer->dump(time++);

	mod->instruction = Vcommon_opcode::tlbwrite << 25; // i-tlb
	mod->eval();
	tracer->dump(time++);

	mod->instruction = Vcommon_opcode::tlbwrite << 25 + 1; // d-tlb
	mod->eval();
	tracer->dump(time++);

	mod->instruction = Vcommon_opcode::iret << 25;
	mod->eval();
	tracer->dump(time++);

	tracer->dump(time++);
	mod->final();
	tracer->close();

	return 0;
}