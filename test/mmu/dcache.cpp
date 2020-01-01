#include <verilated_vcd_c.h>
#include <verilated.h>
#include "Vdcache_directmap.h"
#include <memory>

int main(int argc, char const *argv[])
{
	Verilated::commandArgs(argc, argv);

	// Instantiate module
	std::unique_ptr<Vdcache_directmap> mod(new Vdcache_directmap);

	// Activate waveform tracing
	Verilated::traceEverOn(true);
	std::unique_ptr<VerilatedVcdC> tracer(new VerilatedVcdC);
	mod->trace(tracer.get(), 0);
	tracer->open("dcache_directmap.vcd");

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

	/*
	Data received
	threadid_t thread
	pptr_t paddr

	dtlb_miss
	flag_mem
	flag_store
	flag_isbyte

	mem_ren_en
	pptr_t mem_rec_addr
	cacheline_t mem_rec_cacheline
	*/

	///Reset dCache
	rst = 1;
	tick();
	tick();
	tick();
	rst = 0;

	mod->flag_mem = 1;

	/// Check empty cache, different idx (must miss, two mem requests)
	mod->thread = 0;
	mod->paddr = 0x1000;
	tick();

	mod->thread = 1;
	mod->paddr = 0x1010;
	tick();

	/// Check waiting cacheling (must miss, but must not issue request to memory)
	mod->thread = 2;
	mod->paddr = 0x2000;
	tick();

	/// Answer from memory. Should return the data since it is in memory now
	mod->thread = 3;
	mod->paddr = 0x1010;
	mod->mem_rec_en = 1;
	mod->mem_rec_addr = 0x1010;
	for (auto i = 0; i < 4; i++)
		mod->mem_rec_cacheline[i] = 0xFFFFFFFF;
	tick();

	//Receive an store word request that should miss
	mod->thread = 4;
	mod->mem_rec_en = 0;
	mod->store_en = 1;
	mod->store_isbyte = 0;
	mod->store_addr = 0x6000; //Direction requested
	mod->store_data = 0x1;	//Data to store
	tick();

	//Get data from memory
	mod->store_en = 0;
	mod->mem_rec_en = 1;
	mod->mem_rec_addr = 0x6000;
	for (auto i = 0; i < 4; i++)
		mod->mem_rec_cacheline[i] = 0xFFFFFFFF;
	tick();

	//Receive an store word request that should succed
	mod->mem_rec_en = 0;
	mod->store_addr = 0x1010; //Direction requested
	mod->store_data = 0x1;	//Data to store
	tick();

	//Receive a load and store word at the same time
	mod->flag_store = 0;
	mod->store_en = 1;
	mod->store_isbyte = 0;
	mod->paddr = 0x1010;
	mod->store_addr = 0x6000; //Direction requested to store
	mod->store_data = 0x1;	//Data to store
	tick();

	//Receive two stores word at the same time. One form commiter and other ins TL/C stage
	mod->flag_store = 1;
	mod->store_en = 1;
	mod->store_isbyte = 0;
	mod->paddr = 0x1010;
	mod->store_addr = 0x6000; //Direction requested to store
	mod->store_data = 0x1;	//Data to store
	tick();

	tick();
	mod->final();
	tracer->close();

	return 0;
}
