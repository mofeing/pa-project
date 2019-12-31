#include <verilated_vcd_c.h>
#include <verilated.h>
#include "Vhzu.h"
#include "Vcommon_opcode.h"
#include <memory>

int main(int argc, char const *argv[])
{
	Verilated::commandArgs(argc, argv);

	// Instantiate module
	std::unique_ptr<Vhzu> mod(new Vhzu);

	// Activate waveform tracing
	Verilated::traceEverOn(true);
	std::unique_ptr<VerilatedVcdC> tracer(new VerilatedVcdC);
	mod->trace(tracer.get(), 0);
	tracer->open("hzu.vcd");

	// Tests
	vluint64_t time = 0;
	auto &clk = mod->clk;
	auto &rst = mod->rst;

	auto tick = [&]() {
		clk = 1;
		mod->eval();
		tracer->dump(time++);

		clk = 0;
		mod->eval();
		tracer->dump(time++);
	};

	/// Reset hzu
	rst = 1;
	tick();
	tick();
	tick();
	rst = 0;

	//MISSES

	//If itlb_miss
	mod->instr = (Vcommon_opcode::add << 25) + (4 << 20) + (1 << 15) + (2 << 10); //Instruccion con dst R4
	mod->thread = 0;
	mod->itlb_miss = 1;
	mod->icache_miss = 0;
	tick();

	//If icache_miss
	mod->thread = 1;
	mod->itlb_miss = 0;
	mod->icache_miss = 1;
	tick();
	mod->icache_miss = 0;

	//DRACE

	//If drace of any instruction src1 = previous instruction dst
	// must success
	mod->instr = (Vcommon_opcode::add << 25) + (4 << 20) + (1 << 15) + (2 << 10); //Instruccion con dst R4
	mod->thread = 1;
	tick();

	// must fail
	mod->instr = (Vcommon_opcode::add << 25) + (5 << 20) + (4 << 15) + (2 << 10); //Instruccion con src1 R4
	mod->thread = 1;
	tick();

	//If drace of instruction R src2 = previous instruction dst
	// must success
	mod->instr = (Vcommon_opcode::add << 25) + (6 << 20) + (1 << 15) + (2 << 10); //Instruccion con dst R6
	mod->thread = 2;
	tick();

	// must fail
	mod->instr = (Vcommon_opcode::add << 25) + (7 << 20) + (1 << 15) + (6 << 10); //Instruccion con src2 R6
	mod->thread = 2;
	tick();

	tracer->dump(time++);
	mod->final();
	tracer->close();

	return 0;
}