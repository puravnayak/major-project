# Specification: v3.0 High-Throughput Architecture (2x Unrolled + CSA)

## Objective
Maximize throughput by executing two SHA-256 compression rounds per clock cycle (cutting total round cycles from 64 to 32). Utilize Carry-Save Adders (CSAs) to compress the deep addition chains and maintain a high $F_{max}$.

## Architectural Changes
1. **Dual-Word Message Scheduler (`sha256_w_schedule_unrolled.v`):**
   * Must shift by *two* positions per clock cycle.
   * Must calculate and output *two* words simultaneously: $W_t$ and $W_{t+1}$.
2. **Dual-Constant ROM (`sha256_k_rom_unrolled.v`):**
   * Modified to accept a 5-bit address (0 to 31) and output the concatenated $\{K_{t+1}, K_t\}$.
3. **Unrolled Datapath (`sha256_datapath_unrolled.v`):**
   * Conceptually chains Round A and Round B combinationally.
   * Inputs: $W_t$, $W_{t+1}$, $K_t$, $K_{t+1}$, and the current working variables (A-H).
   * Replaces the critical path additions ($h + \Sigma_1 + Ch + K_t + W_t$) with Carry-Save Adder (CSA) trees. A final Carry-Propagate Adder (CPA) is used only at the end of Round B to resolve the final values for the next register update.
4. **Modified Top FSM (`sha256_top.v`):**
   * The `COMPRESS` state now only runs for 32 clock cycles instead of 64.