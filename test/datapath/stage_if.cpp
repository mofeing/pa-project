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
	tick();
	rst = 0;

	/*
	Data received
	mem_rec_en
	mem_rec_addr
	
	pc[thread]

	mode
	tlbwrite_t flag_tlbwrite
	vpn_t tlbwrite_vpn
	ppn_t tlbwrite_ppn
	*/

	//Thread 1 request instruction in address 0x3000
	//Should give a iTLB_miss
	mod->pc[1] = 0x3000;
	tick();

	//Other threads come after
	mod->pc[2] = 0x4000;
	tick();
	
	mod->pc[3] = 0x5000;
	tick();

	//More cycles until the OS exception handler starts
	//Other threads should be stalled
	tick();
	tick();

	//OS Exception Handler starts
	//Change to superuser mode and receive data for iTLB.
	mod->mode[1] = 1;
	mod->flag_tlbwrite = 1;
	mod->tlbwrite_vpn = ;
	mod->tlbwrite_ppn = ;
	tick();

	//OS Exception handler finishes

	//Try to load again instruction of thread 1 but cache miss
	mod->pc[1]=0x3000;
	mod->mode[1] = 0;
	mod->flag_tlbwrite = 0;
	tick();

	//Other thread tries to launch and icache receive data requested by thread 1
	mod->pc[4]=0x3000;
	mod->mode[1] = 0;
	mod->flag_tlbwrite = 0;
	mod->mem_rec_en = 1;
	mod->mem_rec_addr = ; //Address received
	mod->mem_rec_cacheline = ; //Cacheline received
	tick();

	//Now the instruction of thread 1 should be returned successfully
	mod->pc[1] = 0x3000;
	mod->mem_rec_en = 0;
	tick();

	tick();
	mod->final();
	tracer->close();

	return 0;
}