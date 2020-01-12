#include <verilated_vcd_c.h>
#include <verilated.h>
#include "Vtop.h"
#include <memory>
#include <iomanip>
#include <iostream>

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

	// Profiler
	auto prof_valid = 0;
	auto prof_correctpc = 0;
	auto prof_ilp = 0;

	// Tests
	vluint64_t time = 0;
	auto &clk = mod->clk;
	auto &rst = mod->rst;

	auto tick = [&]() {
		clk = 1;
		mod->eval();
		tracer->dump(time++);

		if (rst == 0)
		{
			prof_valid += mod->top__DOT__tlwb_isvalid;
			prof_correctpc += mod->top__DOT__tlwb_pc == mod->top__DOT__waiting_pc[mod->top__DOT__tlwb_thread];
			prof_ilp += mod->top__DOT__tlwb_isvalid && mod->top__DOT__tlwb_pc == mod->top__DOT__waiting_pc[mod->top__DOT__tlwb_thread];
		}

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

	// Print profile
	std::cout << "Total cycles = " << cycles << std::endl;
	std::cout << "#valid = " << prof_valid << " (" << std::fixed << std::setprecision(1) << float(prof_valid) / cycles * 100 << ")" << std::endl;
	std::cout << "#correct pc = " << prof_correctpc << " (" << std::fixed << std::setprecision(1) << float(prof_correctpc) / cycles * 100 << ")" << std::endl;
	std::cout << "ILP = " << std::setprecision(2) << float(prof_ilp) / cycles << std::endl;

	mod->final();
	tracer->close();
}