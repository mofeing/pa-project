#include <verilated_vcd_c.h>
#include <verilated.h>
#include "Vstage_if.h"
#include <memory>

int main(int argc, char const *argv[])
{
	Verilated::commandArgs(argc, argv);

	// Instantiate module
	std::unique_ptr<Vstage_if> mod(new Vstage_if);

	// Activate waveform tracing
	Verilated::traceEverOn(true);
	std::unique_ptr<VerilatedVcdC> tracer(new VerilatedVcdC);
	mod->trace(tracer.get(), 0);
	tracer->open("stage_if.vcd");

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

	///If_stage reset
	rst = 1;
	tick();
	tick();
	clk = 1;
	mod->eval();
	tracer->dump(time++);
	clk = 0;
	rst = 0;
	mod->pc[0] = 0x1000; // problem simulating rst
	mod->eval();
	tracer->dump(time++);

	mod->pc[0] = 0x1000;
	mod->pc[1] = 0x1010;
	mod->pc[2] = 0x1020;
	mod->pc[3] = 0x1030;
	mod->pc[4] = 0x1040;
	mod->pc[5] = 0x1050;
	mod->pc[6] = 0x1060;
	mod->pc[7] = 0x1070;

	mod->mode = 0b11111111; // all supervisor mode

	for (int i = 0; i < 8; i++)
		tick();

	// I-TLB miss test
	mod->pc[0] = 0x2000;
	mod->pc[1] = 0x2010;
	mod->pc[2] = 0x2020;
	mod->pc[3] = 0x2030;
	mod->pc[4] = 0x2040;
	mod->pc[5] = 0x2050;
	mod->pc[6] = 0x2060;
	mod->pc[7] = 0x2070;

	mod->mode = 0b00000000; // all user mode

	tick();
	tick();
	tick();
	tick();

	//OS Exception Handler starts
	//Change to superuser mode and receive data for iTLB.
	mod->mode = 0b000000100;
	mod->exc_en = 1;
	mod->exc_thread = 2;
	tick();
	tick();
	tick();

	// Simulate effect of TLBWRITE
	mod->tlbwrite_en = 1;
	mod->tlbwrite_vpn = 0x2;
	mod->tlbwrite_ppn = 0x40;
	tick();
	mod->tlbwrite_en = 0;

	// Simulate effect of IRET
	mod->exc_en = 0;
	mod->mode = 0b00000000;
	tick();
	tick();
	tick();

	for (int i = 0; i < 4; i++)
		mod->mem_rec_cacheline[i] = 0xFFFFFFFF;

	// NOTE Load erroneus cache (0x0000)
	mod->mem_rec_en = 1;
	mod->mem_rec_addr = 0x0000;
	tick();

	// Load previous caches (0x100x)
	mod->mem_rec_en = 1;
	for (int i = 0; i < 4; i++)
	{
		mod->mem_rec_addr = 0x1000 + i * 16;
		tick();
	}
	mod->mem_rec_en = 0;

	for (int i = 0; i < 8; i++)
		tick();

	// Load cachelines (0x4000x)
	mod->mem_rec_en = 1;
	for (int i = 0; i < 4; i++)
		mod->mem_rec_cacheline[i] = 0xFFFFFFFF;
	for (int i = 0; i < 4; i++)
	{
		mod->mem_rec_addr = 0x40000 + i * 16;
		tick();
	}

	mod->mem_rec_en = 0;
	for (int i = 0; i < 8; i++)
		tick();

	tick();
	mod->final();
	tracer->close();

	return 0;
}