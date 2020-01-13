#!/bin/bash
mkdir -p build
verilator -Mdir build -sv --trace -Isrc --public --cc src/top.sv --top-module top -Wall -Wno-fatal -Wno-DECLFILENAME -Wno-IMPORTSTAR --exe test/top.cpp -CFLAGS "-std=c++14" && make -C build -f Vtop.mk