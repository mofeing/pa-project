#include <verilated_vcd_c.h>
#include <verilated.h>
#include "Vtop.h"
#include <memory>

int main(int argc, char const *argv[])
{
	Verilated::commandArgs(argc, argv);

	// Instantiate module
	std::unique_ptr<Vtop> mod(new Vtop);

	// Activate waveform tracing
	Verilated::traceEverOn(true);
	std::unique_ptr<VerilatedVcdC> tracer(new VerilatedVcdC);
	mod->trace(tracer.get(), 0);
	tracer->open("top.vcd");

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

	rst = 1;
	tick();
	tick();
	tick();
	rst = 0;

	auto cycles = -4; // NOTE first instruction to propagate lasts 4 cycles
	constexpr auto max_cycles = 20000;
	auto &pc = mod->top__DOT__waiting_pc;

	while (!Verilated::gotFinish() && cycles++ < max_cycles)
		tick();
	tick();

	mod->final();
	tracer->close();
}