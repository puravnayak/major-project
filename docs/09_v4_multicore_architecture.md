# Specification: v4.0 Multicore Architecture (Dual-Core)

## Objective
Double the total throughput by instantiating multiple parallel cores[cite: 1]. This design will wrap two independent v3.0 (2x unrolled) cores inside a single top-level module.

## Module: `sha256_multicore_top.v`
* **Core Instantiations:** Instantiate two copies of the v3 top-level module (`core_0` and `core_1`). 
* **Inputs:** 
  * `clk`, `rst` (Shared across both cores)
  * `valid_in` (Shared dispatcher signal)
  * `block_in_0[511:0]`, `block_in_1[511:0]` (Independent data streams)
* **Outputs:**
  * `hash_out_0[255:0]`, `hash_out_1[255:0]`
  * `valid_out_0`, `valid_out_1`

## Expected PPA Impact
* **Throughput:** Should double compared to v3 (Processing 1024 bits per 33 cycles instead of 512).
* **Area & Power:** Should exactly double compared to v3.
* **Energy per Hash:** Should remain virtually identical to v3, proving linear scalability.