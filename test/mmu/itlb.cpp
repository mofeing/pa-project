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

	/// Reset iTLB
	rst = 1;
	tick();
	tick();
	tick();
	rst = 0;

	// Supervisor mode
	mod->mode = 1;
	mod->vaddr = 0x1000;
	tick();

	mod->vaddr = 0x2000;
	tick();

	// User mode
	mod->mode = 0;
	mod->vaddr = 0x1000;
	tick();

	mod->vaddr = 0x2000;
	mod->write_en = 1;
	mod->write_vpn = 0x1;
	mod->write_ppn = 0x40;
	tick();

	mod->vaddr = 0x1001;
	mod->write_en = 0;
	tick();

	tick();
	mod->final();
	tracer->close();

	return 0;
}
