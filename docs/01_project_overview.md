# Project: Energy-Efficient SHA-256 Cryptographic Accelerator

## Objective
Design, implement, and optimize a SHA-256 hardware architecture prototyped on an FPGA, targeting an optimal trade-off between throughput, power, and area (PPA). The project explores the PPA space by evaluating different architectures against a baseline.

## Target Platform
* **Board:** TUL PYNQ-Z2 Development Board
* **FPGA Device:** Xilinx Zynq-7000 SoC (`xc7z020clg400-1`)
* **Package:** CLG400, Speed Grade -1
* **Available Resources:** 53,200 LUTs, 106,400 Flip-Flops, 140 Block RAMs (36Kb each), 220 DSP slices

## Architectural Versions
The project will be built iteratively:
* **v1.0 (Baseline):** 1 round/cycle, standard adders, block RAM message schedule.
* **v2.0 (IoT Edge):** Area/power optimized (folding, on-the-fly scheduling, clock gating).
* **v3.0 (High Throughput):** Performance optimized (loop unrolling, pipelining, carry-save adders).
* **v4.0 (Balanced):** The final hybrid architecture targeting the lowest Energy per Hash.

## Current Phase: Phase 1 (Golden Reference)
We are building a purely functional C++ software model of SHA-256. This model will not be synthesized. Its sole purpose is to generate known-good test vectors (inputs, intermediate round states, and final hashes) to verify our future Verilog RTL testbenches.