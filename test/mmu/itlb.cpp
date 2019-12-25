#include <verilated_vcd_c.h>
#include <verilated.h>
#include "Vitlb.h"
#include <memory>

int main(int argc, char const *argv[])
{
	Verilated::commandArgs(argc, argv);

	// Instantiate module
	std::unique_ptr<Vitlb> mod(new Vitlb);

	// Activate waveform tracing
	Verilated::traceEverOn(true);
	std::unique_ptr<VerilatedVcdC> tracer(new VerilatedVcdC);
	mod->trace(tracer.get(), 0);
	tracer->open("itlb.vcd");

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

	/// Reset TLB
	rst = 1;
	clk = 1;
	mod->eval();
	tracer->dump(time++);

	clk = 0;
	rst = 0;
	mod->eval();
	tracer->dump(time++);

	/// Check translation in supervisor mode (bypass)
	mod->mode = 1;
	mod->vaddr = 0x0;
	tick();

	mod->vaddr = 0x1000;
	tick();

	mod->vaddr = 0x22222;
	tick();

	/// Check translation in user mode (must miss)
	mod->mode = 0;
	mod->vaddr = 0x0;
	tick();

	mod->vaddr = 0x1000;
	tick();

	/// TLBwrite
	mod->write_en = 1;
	mod->write_vpn = 0x1000 >> 6;
	mod->write_ppn = 0x20;
	tick();

	mod->write_en = 0;
	tick();

	tick();
	mod->final();
	tracer->close();

	return 0;
}
