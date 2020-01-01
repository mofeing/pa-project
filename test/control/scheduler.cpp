#include <verilated_vcd_c.h>
#include <verilated.h>
#include "Vscheduler_roundrobin.h"
#include <memory>

int main(int argc, char const *argv[])
{
	Verilated::commandArgs(argc, argv);

	// Instantiate module
	std::unique_ptr<Vscheduler_roundrobin> mod(new Vscheduler_roundrobin);

	// Activate waveform tracing
	Verilated::traceEverOn(true);
	std::unique_ptr<VerilatedVcdC> tracer(new VerilatedVcdC);
	mod->trace(tracer.get(), 0);
	tracer->open("scheduler_roundrobin.vcd");

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

	// 10 cycles in reset
	rst = 1;
	for (auto i = 0; i < 10; i++)
		tick();

	// 10 cycles normal scheduling
	rst = 0;
	for (auto i = 0; i < 10; i++)
		tick();

	// 10 cycles forced-scheduling
	mod->exc_en = 1;
	mod->exc_thread = 4;
	for (auto i = 0; i < 10; i++)
		tick();

	// 10 cycles of return to normal scheduling
	mod->exc_en = 0;
	for (auto i = 0; i < 10; i++)
		tick();

	tracer->dump(time++);
	mod->final();
	tracer->close();

	return 0;
}