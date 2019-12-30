#include <verilated_vcd_c.h>
#include <verilated.h>
#include "Vdtlb.h"
#include <memory>

int main(int argc, char const *argv[])
{
	Verilated::commandArgs(argc, argv);

	// Instantiate module
	std::unique_ptr<Vdtlb> mod(new Vdtlb);

	// Activate waveform tracing
	Verilated::traceEverOn(true);
	std::unique_ptr<VerilatedVcdC> tracer(new VerilatedVcdC);
	mod->trace(tracer.get(), 0);
	tracer->open("dtlb.vcd");

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

	/// Reset dTLB
	rst = 1;
	clk = 1;
	mod->eval();
	tracer->dump(time++);

	clk = 0;
	rst = 0;
	mod->eval();
	tracer->dump(time++);

	/// Check translation in supervisor mode (bypass)
	mod->mode = 1;
	mod->vaddr = 0x0;
	tick();

	mod->vaddr = 0x1000;
	tick();

	mod->vaddr = 0x22222;
	tick();

	/// Check translation in user mode (must miss)
	mod->mode = 0;
	mod->vaddr = 0x0;
	tick();

	mod->vaddr = 0x1000;
	tick();

	/// TLBwrite correct
    mod->mode = 1
	mod->write_en = 1;
    mod->is_valid = 1;
    mod->flag_mem = 1;
	mod->write_vpn = 0x1000 >> 6;
	mod->write_ppn = 0x20;
	tick();

    // TLBwrite fail (not supervisor mode)
	mod->mode = 0
	mod->write_en = 1;
    mod->is_valid = 1;
    mod->flag_mem = 1;
	mod->write_vpn = 0x1000 >> 6;
	mod->write_ppn = 0x20;
	tick();

    // TLBwrite fail (not write enabled)
	mod->mode = 1
	mod->write_en = 0;
    mod->is_valid = 1;
    mod->flag_mem = 1;
	mod->write_vpn = 0x1000 >> 6;
	mod->write_ppn = 0x20;
	tick();

    // TLBwrite fail (not valid)
	mod->mode = 1
	mod->write_en = 1;
    mod->is_valid = 0;
    mod->flag_mem = 1;
	mod->write_vpn = 0x1000 >> 6;
	mod->write_ppn = 0x20;
	tick();

    // TLBwrite fail (not flag_mem)
	mod->mode = 1
	mod->write_en = 1;
    mod->is_valid = 1;
    mod->flag_mem = 0;
	mod->write_vpn = 0x1000 >> 6;
	mod->write_ppn = 0x20;
	tick();

    //RETURN PHISICAL ADDRESS
    //First it has it *
    mod->write_vpn = 0x1000 >> 6;
	mod->write_ppn = 0x20;

    //Return phisical address (It has it and correct)
    mod->mode = 0;
    mod->is_valid = 1;
    mod->flag_mem = 1;
    mod->vaddr = ; //Direccion a pedir
    mod->is_valid = 1;
	tick();

    //Return phisical address (It has it but Not valid)



    //Return phisical address (It has it but no flag_mem)

    
    //Does not have it *

    //iTLB miss
    mod->mode = 0;
    mod->is_valid = 1;
    mod->flag_mem = 1;
    mod->vaddr = 0x0FFFF; //Direccion a pedir
    mod->is_valid = 1;
	tick();
    tick();

	tick();
	mod->final();
	tracer->close();

	return 0;
}