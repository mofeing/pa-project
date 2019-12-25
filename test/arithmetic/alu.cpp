#include <verilated_vcd_c.h> // this header has to be before verilated.h
#include <verilated.h>
#include "Valu.h"
#include "Vcommon_func.h"
#include <memory>

int main(int argc, char const *argv[])
{
	Verilated::commandArgs(argc, argv);

	// Instantiate module
	std::unique_ptr<Valu> mod(new Valu);

	// Activate waveform tracing
	Verilated::traceEverOn(true);
	std::unique_ptr<VerilatedVcdC> tfp(new VerilatedVcdC);
	mod->trace(tfp.get(), 0);
	tfp->open("alu.vcd");

	// Tests
	vluint64_t time = 0;

	mod->a = 7;
	mod->b = 4;

	mod->alu_func = Vcommon_func::land;
	mod->eval();
	tfp->dump(time++);

	mod->alu_func = Vcommon_func::lor;
	mod->eval();
	tfp->dump(time++);

	mod->alu_func = Vcommon_func::lnor;
	mod->eval();
	tfp->dump(time++);

	mod->alu_func = Vcommon_func::add;
	mod->eval();
	tfp->dump(time++);

	mod->alu_func = Vcommon_func::sub;
	mod->eval();
	tfp->dump(time++);

	mod->alu_func = Vcommon_func::slt;
	mod->eval();
	tfp->dump(time++);

	// End testbench
	tfp->dump(time++);
	mod->final();
	tfp->close();

	return 0;
}
