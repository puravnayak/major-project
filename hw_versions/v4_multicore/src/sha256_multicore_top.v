`timescale 1ns / 1ps

/**
 * ============================================================================
 * Module: sha256_multicore_top
 * Description: Dual-Core Parallel SHA-256 Cryptographic Accelerator (v4.0).
 *              Integrates two independent v3.0 (2x unrolled + CSA) execution
 *              engines under a unified dispatcher interface to double hashing
 *              throughput to 1024 bits per 33 clock cycles.
 * Specification: docs/09_v4_multicore_architecture.md
 * Target: Xilinx Zynq-7000 FPGA (xc7z020clg400-1, PYNQ-Z2)
 * ============================================================================
 */

module sha256_multicore_top (
    input  wire         clk,
    input  wire         rst,
    input  wire         valid_in,          // Shared dispatcher valid pulse
    input  wire [511:0] block_in_0,        // Core 0 512-bit message stream
    input  wire [511:0] block_in_1,        // Core 1 512-bit message stream
    output wire [5:0]   round_out_0,       // Core 0 active round/step index
    output wire [5:0]   round_out_1,       // Core 1 active round/step index
    output wire [255:0] intermediate_out_0,// Core 0 working variable state
    output wire [255:0] intermediate_out_1,// Core 1 working variable state
    output wire [255:0] hash_out_0,        // Core 0 computed 256-bit digest
    output wire [255:0] hash_out_1,        // Core 1 computed 256-bit digest
    output wire         valid_out_0,       // Core 0 output valid handshake
    output wire         valid_out_1        // Core 1 output valid handshake
);

    // ------------------------------------------------------------------------
    // Core Instance 0: Independent 2x Unrolled SHA-256 Engine
    // ------------------------------------------------------------------------
    sha256_core_engine core_0 (
        .clk                    (clk),
        .rst                    (rst),
        .valid_in               (valid_in),
        .block_in               (block_in_0),
        .round_out              (round_out_0),
        .intermediate_state_out (intermediate_out_0),
        .hash_out               (hash_out_0),
        .valid_out              (valid_out_0)
    );

    // ------------------------------------------------------------------------
    // Core Instance 1: Independent 2x Unrolled SHA-256 Engine
    // ------------------------------------------------------------------------
    sha256_core_engine core_1 (
        .clk                    (clk),
        .rst                    (rst),
        .valid_in               (valid_in),
        .block_in               (block_in_1),
        .round_out              (round_out_1),
        .intermediate_state_out (intermediate_out_1),
        .hash_out               (hash_out_1),
        .valid_out              (valid_out_1)
    );

endmodule
