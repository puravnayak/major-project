# Specification: v2.0 IoT Edge Architecture (On-the-Fly Scheduling)

## Objective
Replace the static 64-word message array from v1.0 with a highly area-efficient 16-word sliding window scheduler to drastically reduce Flip-Flop (FF) utilization.

## Module: `sha256_w_schedule.v` (v2.0)
* **Core Structure:** A 16-word shift register array (each word is 32 bits).
* **Inputs:** `clk`, `rst`, `enable`, `load` (to grab the initial 512-bit block), `block_in[511:0]`.
* **Output:** `w_out[31:0]` (The specific $W_t$ for the current round).

## Operational Logic
* **Load Phase:** When `load` is HIGH, initialize the 16 registers with the 16 words of `block_in`.
* **Rounds 0-15:** Output the oldest word in the register (Word 0). Shift the registers so Word 1 becomes the new Word 0.
* **Rounds 16-63:** 
  * Calculate the new word: $W_t = \sigma_1(W_{14}) + W_{9} + \sigma_0(W_{1}) + W_{0}$ (indexed based on their position in the current sliding window).
  * Output this new $W_t$.
  * Shift the array, pushing the oldest word out and inserting the new $W_t$ at the top (Word 15).