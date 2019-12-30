#include <verilated_vcd_c.h>
#include <verilated.h>
#include "Vhzu.h"
#include <memory>

int main(int argc, char const *argv[])
{
	Verilated::commandArgs(argc, argv);

	// Instantiate module
	std::unique_ptr<Vhzu> mod(new Vhzu);

	// Activate waveform tracing
	Verilated::traceEverOn(true);
	std::unique_ptr<VerilatedVcdC> tracer(new VerilatedVcdC);
	mod->trace(tracer.get(), 0);
	tracer->open("hzu.vcd");

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

    /// Reset hzu
    rst = 1;
    tick();
    tick();
    tick();
    rst = 0;

    //MISSES

    //If itlb_miss
    i_tlb_miss = 1;
    i_cache_miss = 0;
    tick();

    //If icache_miss
    i_tlb_miss = 0;
    i_cache_miss = 1;
    tick();

    //DRACE

    //If drace of any instruction src1 = previous instruction dst
    mod->instruction = Vcommon_opcode::add << 25 + 4 << 20 + 1 << 15 + 2 << 10; //Instruccion con dst R4
    tick();
    mod->instruction = Vcommon_opcode::add << 25 + 5 << 20 + 4 << 15 + 2 << 10; //Instruccion con src1 R4
    tick();

    //If drace of instruction R src2 = previous instruction dst
    mod->instruction = Vcommon_opcode::add << 25 + 6 << 20 + 1 << 15 + 2 << 10; //Instruccion con dst R6
    tick();
    mod->instruction = Vcommon_opcode::add << 25 + 7 << 20 + 1 << 15 + 6 << 10; //Instruccion con src2 R6
    tick();

    //NO STORE/LOAD AFTER STORE

    //If Load word after Store word
    mod->instruction = Vcommon_opcode::stw << 25;
    tick();
    mod->instruction = Vcommon_opcode::ldw << 25;
    tick();

    //If Store word after Store word
    mod->instruction = Vcommon_opcode::stw << 25;
    tick();
    mod->instruction = Vcommon_opcode::stw << 25;
    tick();

    //If Load byte after store word
    mod->instruction = Vcommon_opcode::stw << 25;
    tick();
    mod->instruction = Vcommon_opcode::ldb << 25;
    tick();

    //If Store byte after store word
    mod->instruction = Vcommon_opcode::stw << 25;
    tick();
    mod->instruction = Vcommon_opcode::stb << 25;
    tick();

    //If Load word after Store byte
    mod->instruction = Vcommon_opcode::stb << 25;
    tick();
    mod->instruction = Vcommon_opcode::ldw << 25;
    tick();
    
    //If Store word after Store byte
    mod->instruction = Vcommon_opcode::stb << 25;
    tick();
    mod->instruction = Vcommon_opcode::stw << 25;
    tick();

    //If Load byte after store byte
    mod->instruction = Vcommon_opcode::stb << 25;
    tick();
    mod->instruction = Vcommon_opcode::ldb << 25;
    tick();

    //If Store byte after store byte
    mod->instruction = Vcommon_opcode::stb << 25;
    tick();
    mod->instruction = Vcommon_opcode::stb << 25;
    tick();

	tracer->dump(time++);
	mod->final();
	tracer->close();

	return 0;
}