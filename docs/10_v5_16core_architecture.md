# Specification: v5.0 16-Core Mega-Array Architecture

## Objective
Discard the logic-level power optimizations and focus entirely on maximizing the PPA throughput trade-off by scaling to a 16-core parallel architecture[cite: 1]. This design targets the Xilinx ZYNQ XC7Z020 FPGA on the PYNQ-Z2 board, utilizing a significant portion of its available 53,200 LUTs.

## Module: `sha256_16core_top.v`
* **Core Instantiations:** Use a Verilog `generate` block to instantiate 16 independent copies of the v3.0 (2x unrolled) core (`core_0` through `core_15`).
* **Inputs:** 
  * `clk`, `rst` (Shared clock tree across all 16 cores).
  * `valid_in` (Shared start signal).
  * `block_in [0:15][511:0]` (SystemVerilog 2D array or a single flat `[8191:0]` bus for the 16 independent data streams).
* **Outputs:**
  * `hash_out [0:15][255:0]` or flat `[4095:0]`.
  * `valid_out_bus [15:0]`.