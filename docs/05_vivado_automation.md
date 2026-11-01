# Specification: Vivado Automation & PPA Extraction TCL

## Objective
Create a TCL script (`run_synth.tcl`) that runs Vivado in batch mode to synthesize the RTL, generate timing/utilization reports, run a post-synthesis simulation to generate a `.saif` switching activity file, and calculate accurate power.

## Flow Requirements
1. **Project Setup:** 
   * Create an in-memory or physical project targeting the PYNQ-Z2 board (Xilinx Zynq-7000 series `xc7z020clg400-1`, board part `tul.com.tw:pynq-z2:part0:1.0`).
   * Read all Verilog files in `../src/` and `../tb/`.
2. **Synthesis & Constraints:**
   * Synthesize the design with `sha256_top` as the top module.
   * Apply a virtual clock constraint of 100MHz (10.0ns period) to the `clk` port using `create_clock` so the timing engine can calculate the Worst Negative Slack (WNS).
3. **Initial Reports (Area & Timing):**
   * Generate `post_synth_utilization.rpt` for LUT/FF counts.
   * Generate `post_synth_timing.rpt` for $F_{max}$ calculations.
4. **Activity & Power (Crucial for Energy per Hash):**
   * Launch the `xsim` simulator via TCL to run `tb_sha256`.
   * Log switching activity to `v1_activity.saif`.
   * Read the `.saif` file back into the synthesized design.
   * Generate `post_synth_power.rpt` based on actual toggle rates.