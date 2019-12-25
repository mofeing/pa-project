#include <verilated_vcd_c.h> // this header has to be before verilated.h
#include <verilated.h>
#include "Vmultiplier.h"
#include <memory>
#include <iostream>

int main(int argc, char const *argv[])
{
	Verilated::commandArgs(argc, argv);

	// Instantiate module
	std::unique_ptr<Vmultiplier> mod(new Vmultiplier);

	// Activate waveform tracing
	Verilated::traceEverOn(true);
	std::unique_ptr<VerilatedVcdC> tfp(new VerilatedVcdC);
	mod->trace(tfp.get(), 0);
	tfp->open("multiplier.vcd");

	// Tests
	vluint64_t time = 0;

	mod->a = 0;
	mod->b = 0;
	mod->eval();
	std::cout << "[" << time << "] a=" << mod->a << ", b=" << mod->b << " - c=" << mod->c << std::endl;
	tfp->dump(time++);

	mod->a = 1;
	mod->b = 0;
	mod->eval();
	std::cout << "[" << time << "] a=" << mod->a << ", b=" << mod->b << " - c=" << mod->c << std::endl;
	tfp->dump(time++);

	mod->a = 0;
	mod->b = 1;
	mod->eval();
	std::cout << "[" << time << "] a=" << mod->a << ", b=" << mod->b << " - c=" << mod->c << std::endl;
	tfp->dump(time++);

	mod->a = ~((uint32_t)0);
	mod->b = ~((uint32_t)0);
	mod->eval();
	std::cout << "[" << time << "] a=" << mod->a << ", b=" << mod->b << " - c=" << mod->c << std::endl;
	tfp->dump(time++);

	mod->b = 1;
	mod->eval();
	std::cout << "[" << time << "] a=" << mod->a << ", b=" << mod->b << " - c=" << mod->c << std::endl;
	tfp->dump(time++);

	mod->a = 5;
	mod->b = 4;
	mod->eval();
	std::cout << "[" << time << "] a=" << mod->a << ", b=" << mod->b << " - c=" << mod->c << std::endl;
	tfp->dump(time++);

	// End testbench
	tfp->dump(time++);
	mod->final();
	tfp->close();

	return 0;
}
