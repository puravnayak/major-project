# Specification: v1.0 Baseline Architecture

## Module Hierarchy
1. `sha256_top.v`: The top-level wrapper and FSM controller. Interfaces directly with the testbench.
2. `sha256_datapath.v`: Contains the 8 working variables (A-H) and the combinational logic for a single compression round (Ch, Maj, Sigma0, Sigma1). Uses standard behavioral adders (`+`).
3. `sha256_w_schedule.v`: Expands the 512-bit input block into 64 32-bit words ($W_t$). For v1.0, use a standard 64-word register array initialized upon block load, outputting the correct $W_t$ based on the round counter.
4. `sha256_k_rom.v`: A simple read-only lookup table containing the sixty-four 32-bit $K_t$ constants.

## Finite State Machine (FSM) inside `sha256_top`
* **IDLE:** Wait for `valid_in` to be HIGH.
* **INIT (1 cycle):** 
  * Load `block_in` into the message scheduler.
  * Load the initial hash values (H0-H7) into the datapath working variables (A-H).
  * Reset round counter to 0.
* **COMPRESS (64 cycles):**
  * Enable the datapath to compute the next A-H state each cycle.
  * Feed $W_t$ and $K_t$ into the datapath based on the round counter.
  * Increment round counter.
  * Expose the concatenated A-H state to `intermediate_state_out` for the testbench.
* **UPDATE (1 cycle):** Add the final A-H working variables to the saved H0-H7 hash state using standard 32-bit adders.
* **DONE (1 cycle):** Assert `valid_out` HIGH, expose the final concatenated hash to `hash_out`, and return to IDLE.