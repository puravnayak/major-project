# Specification: v6.0 Micro-Edge Architecture (8-bit Folded)

## Objective
Target extreme resource-constrained IoT devices (e.g., coin-cell sensors). Minimize peak power consumption (Watts) and physical area (LUTs) by serializing the datapath.

## Architectural Changes
1. **8-bit Folded Datapath (`sha256_datapath_8bit.v`):**
   * Replace all 32-bit Carry-Propagate Adders with 8-bit adders.
   * Use internal shift registers to accumulate the 32-bit results over 4 clock cycles per SHA-256 round.
2. **Top-Level FSM (`sha256_top_8bit.v`):**
   * The `COMPRESS` state now takes 256 cycles (64 rounds × 4 cycles/round).
3. **Clocking:**
   * The target clock frequency for synthesis will be explicitly lowered to 10 MHz (100.0 ns period) to model standard low-power IoT microcontrollers.