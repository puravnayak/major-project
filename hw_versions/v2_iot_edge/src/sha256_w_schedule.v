`timescale 1ns / 1ps

/**
 * ============================================================================
 * Module: sha256_w_schedule
 * Description: Message Scheduler for SHA-256 v2.0 IoT Edge Architecture.
 *              Implements a 16-word sliding window shift register to compute
 *              W_t on-the-fly, reducing register utilization from 64 words
 *              (2048 FFs) in v1.0 down to 16 words (512 FFs).
 * Specification: docs/07_v2_iot_architecture.md
 *
 * Operational Logic:
 *  - Load Phase (load == 1):
 *      Initializes w[0..15] with the 16 32-bit words from block_in[511:0].
 *  - Rounds 0..15 (round < 16, enable == 1):
 *      Outputs w[0]. Shifts array left (w[i] <= w[i+1]), recirculating w[0]
 *      into w[15]. After 16 rounds, the original 16 words are in their
 *      initial positions.
 *  - Rounds 16..63 (round >= 16, enable == 1):
 *      Computes W_new = sigma1(w[14]) + w[9] + sigma0(w[1]) + w[0].
 *      Outputs W_new. Shifts array left, pushing W_new into w[15].
 * ============================================================================
 */

module sha256_w_schedule (
    input  wire         clk,
    input  wire         rst,
    input  wire         enable,      // Advance schedule shift register (active in COMPRESS state)
    input  wire         load,        // Load initial 512-bit block (active in INIT state)
    input  wire [511:0] block_in,    // 512-bit padded message block
    input  wire [5:0]   round,       // Current round index [0..63]
    output wire [31:0]  w_out        // Selected W_t word for current round
);

    // ------------------------------------------------------------------------
    // 1. SHA-256 Bitwise Transformation Functions (Pure Combinational Logic)
    // ------------------------------------------------------------------------

    // Right rotation (ROTR)
    function [31:0] rotr;
        input [31:0] x;
        input [4:0]  n;
        begin
            rotr = (x >> n) | (x << (32 - n));
        end
    endfunction

    // sigma0(x) = ROTR^7(x) ^ ROTR^18(x) ^ SHR^3(x)
    function [31:0] sigma0;
        input [31:0] x;
        begin
            sigma0 = rotr(x, 5'd7) ^ rotr(x, 5'd18) ^ (x >> 3);
        end
    endfunction

    // sigma1(x) = ROTR^17(x) ^ ROTR^19(x) ^ SHR^10(x)
    function [31:0] sigma1;
        input [31:0] x;
        begin
            sigma1 = rotr(x, 5'd17) ^ rotr(x, 5'd19) ^ (x >> 10);
        end
    endfunction

    // ------------------------------------------------------------------------
    // 2. 16-Stage Shift Register Array
    // ------------------------------------------------------------------------
    reg [31:0] w [0:15];

    // ------------------------------------------------------------------------
    // 3. Combinational Expansion Logic for Rounds 16..63
    // ------------------------------------------------------------------------
    // Relative window indices:
    //   w[0]  corresponds to W_{t-16}
    //   w[1]  corresponds to W_{t-15}
    //   w[9]  corresponds to W_{t-7}
    //   w[14] corresponds to W_{t-2}
    wire [31:0] s0;
    wire [31:0] s1;
    wire [31:0] w_new;

    assign s0    = sigma0(w[1]);
    assign s1    = sigma1(w[14]);
    assign w_new = s1 + w[9] + s0 + w[0];

    // Round Output Multiplexer:
    // - Rounds 0..15: oldest word currently at w[0]
    // - Rounds 16..63: newly evaluated W_t word
    assign w_out = (round < 6'd16) ? w[0] : w_new;

    // ------------------------------------------------------------------------
    // 4. Sequential Shift Register Control
    // ------------------------------------------------------------------------
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1) begin
                w[i] <= 32'd0;
            end
        end else if (load) begin
            // Big-endian unpacking of 512-bit block into 16 32-bit registers
            w[0]  <= block_in[511:480];
            w[1]  <= block_in[479:448];
            w[2]  <= block_in[447:416];
            w[3]  <= block_in[415:384];
            w[4]  <= block_in[383:352];
            w[5]  <= block_in[351:320];
            w[6]  <= block_in[319:288];
            w[7]  <= block_in[287:256];
            w[8]  <= block_in[255:224];
            w[9]  <= block_in[223:192];
            w[10] <= block_in[191:160];
            w[11] <= block_in[159:128];
            w[12] <= block_in[127:96];
            w[13] <= block_in[95:64];
            w[14] <= block_in[63:32];
            w[15] <= block_in[31:0];
        end else if (enable) begin
            // Shift array: Word 1 becomes Word 0, ..., Word 15 becomes Word 14
            for (i = 0; i < 15; i = i + 1) begin
                w[i] <= w[i+1];
            end

            // Insert into the top register (Word 15):
            // - Rounds 0..15: circular feedback of oldest word (w[0])
            // - Rounds 16..63: newly calculated W_t word
            w[15] <= (round < 6'd16) ? w[0] : w_new;
        end
    end

endmodule
