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

	/// TLBwrite correct SUCCESS
    mod->mode = 1
	mod->write_en = 1;
	mod->write_vpn = 0x1000 >> 6;
	mod->write_ppn = 0x20;
	tick();
	tick();

    // TLBwrite fail (not supervisor mode) FAILURE
	mod->mode = 0
	mod->write_en = 1;
	mod->write_vpn = 0x1000 >> 6;
	mod->write_ppn = 0x20;
	tick();
	tick();

    //RETURN PHISICAL ADDRESS
    //It has it and user mode *
    //Previous vpn: mod->write_vpn = 0x1000 >> 6;
	//Previous ppn: mod->write_ppn = 0x20;

    //Return phisical address (It has it and correct) SUCCESS
    mod->mode = 0;
    mod->vaddr = 0x00400000; //Address requested
	tick();
	tick();

	//It has it and supervisor mode *
	//Return phisical address (It has it and correct) SUCCESS
	mod->mode = 1;
	tick();
    tick();

    //Does not have it and user mode *
    //iTLB miss FAILURE
	mod->mode = 0;
    mod->vaddr = 0x0FFFFFFF; //Address requested
	tick();
    tick();

	//Does not have it and supervisor mode * SUCCESS
	mod->mode = 1;
	tick();
	tick();

	tick();
	mod->final();
	tracer->close();

	return 0;
}
