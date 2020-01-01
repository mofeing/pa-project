#include <verilated_vcd_c.h>
#include <verilated.h>
#include "Vdcache_directmap.h"
#include <memory>

int main(int argc, char const *argv[])
{
	Verilated::commandArgs(argc, argv);

	// Instantiate module
	std::unique_ptr<Vdcache_directmap> mod(new Vdcache_directmap);

	// Activate waveform tracing
	Verilated::traceEverOn(true);
	std::unique_ptr<VerilatedVcdC> tracer(new VerilatedVcdC);
	mod->trace(tracer.get(), 0);
	tracer->open("dcache_directmap.vcd");

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

	///Reset dCache
	rst = 1;
	tick();
	tick();
	tick();
	rst = 0;

	/// Check empty cache, different idx (must miss, two mem requests)
	mod->thread = 0;
	mod->paddr = 0x1000;
	tick();

	mod->thread = 1;
	mod->paddr = 0x1010;
	tick();

	/// Check waiting cacheling (must miss, but must not issue request to memory)
	mod->thread = 2;
	mod->paddr = 0x2000;
	tick();

	/// Answer from memory
	mod->thread = 3;
	mod->paddr = 0x1010;
	mod->mem_rec_en = 1;
	mod->mem_rec_addr = 0x1010;
	for (auto i = 0; i < 4; i++)
		mod->mem_rec_cacheline[i] = 0xFFFFFFFF;
	tick();

	mod->thread = 4;
	mod->mem_rec_en = 0;
	tick();

	mod->final();
	tracer->close();

	return 0;
}