#include <verilated_vcd_c.h>
#include <verilated.h>
#include "Vregfile.h"
#include <memory>

int main(int argc, char const *argv[])
{
	Verilated::commandArgs(argc, argv);

	// Instantiate module
	std::unique_ptr<Vregfile> mod(new Vregfile);

	// Activate waveform tracing
	Verilated::traceEverOn(true);
	std::unique_ptr<VerilatedVcdC> tracer(new VerilatedVcdC);
	mod->trace(tracer.get(), 0);
	tracer->open("regfile.vcd");

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

	/// Reset
	rst = 1;
	clk = 1;
	mod->eval();
	tracer->dump(time++);

	clk = 0;
	rst = 0;
	mod->eval();
	tracer->dump(time++);

	///
	mod->w_enable = true;
	mod->w_addr = 0;
	mod->w_data = 10;
	tick();

	mod->w_enable = false;
	tick();

	tick();
	mod->final();
	tracer->close();

	return 0;
}
