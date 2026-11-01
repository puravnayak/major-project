# Specification: C++ Golden Reference Model

## Core Requirements
* Must implement the standard SHA-256 algorithm.
* Must be written in clean, modern C++ (C++17 or later) using `<cstdint>` for precise bit-width control (e.g., `uint32_t`).
* Must process string inputs and file inputs.

## Hardware Verification I/O (Crucial)
The model must write its execution state to three separate `.txt` files in zero-padded hexadecimal format to enable automated Verilog testbench verification.

1. **`input_vectors.txt`**: 
   * Contains the fully padded 512-bit (64-byte) message blocks.
   * Format: One 512-bit block per line, represented as 16 contiguous 32-bit hex words.

2. **`intermediate_states.txt`**: 
   * Captures the state of the 8 working variables (A, B, C, D, E, F, G, H) after *each* of the 64 rounds of the compression function.
   * Format: `Round_Number: A B C D E F G H` (all in 32-bit hex). 
   * Must include a block delimiter if multiple 512-bit blocks are processed.

3. **`final_hashes.txt`**: 
   * The final 256-bit hash after adding the compressed chunk to the current hash state.
   * Format: One 256-bit hash per line (64 hex characters).