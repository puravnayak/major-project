`timescale 1ns / 1ps

/**
 * ============================================================================
 * Module: sha256_16core_top
 * Description: 16-Core Mega-Array Parallel SHA-256 Accelerator Architecture (v5.0).
 *              Instantiates 16 independent 2x-unrolled SHA-256 cores using a
 *              Verilog-2001 generate loop, processing 16 * 512 = 8192 bits
 *              simultaneously in 33 clock cycles.
 * Specification: docs/10_v5_16core_architecture.md
 * Target: Xilinx Zynq-7000 FPGA (xc7z020clg400-1, PYNQ-Z2)
 * ============================================================================
 */

module sha256_16core_top (
    input  wire          clk,
    input  wire          rst,
    input  wire          valid_in,
    input  wire [8191:0] block_in,
    output wire [4095:0] hash_out,
    output wire [15:0]   valid_out_bus
);

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_cores
            sha256_top u_core (
                .clk                    (clk),
                .rst                    (rst),
                .valid_in               (valid_in),
                .block_in               (block_in[i*512 +: 512]),
                .round_out              (), // Internal round tracking not exposed
                .intermediate_state_out (), // Intermediate state not exposed at top
                .hash_out               (hash_out[i*256 +: 256]),
                .valid_out              (valid_out_bus[i])
            );
        end
    endgenerate

endmodule
