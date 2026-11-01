`timescale 1ns / 1ps

/**
 * ============================================================================
 * Module: sha256_w_schedule_unrolled
 * Description: 2x Unrolled Dual-Word Message Scheduler for SHA-256 v3.0.
 *              Maintains a 16-word sliding window that shifts by two words
 *              every clock cycle to simultaneously output W_t and W_{t+1}.
 * Specification: docs/08_v3_throughput_architecture.md
 * ============================================================================
 */

module sha256_w_schedule_unrolled (
    input  wire         clk,
    input  wire         rst,
    input  wire         enable,      // Advance scheduler by 2 words (COMPRESS state)
    input  wire         load,        // Load 512-bit message block (INIT state)
    input  wire [511:0] block_in,    // 512-bit message block
    input  wire [4:0]   step,        // Step counter [0..31] (representing rounds 2*step and 2*step+1)
    output wire [31:0]  w_t,         // Message word for Round A (2*step)
    output wire [31:0]  w_t_plus_1   // Message word for Round B (2*step + 1)
);

    // ------------------------------------------------------------------------
    // 1. Bitwise Rotations and Sigma Functions
    // ------------------------------------------------------------------------
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
    // 2. 16-Word Shift Register Window
    // ------------------------------------------------------------------------
    reg [31:0] w [0:15];

    // ------------------------------------------------------------------------
    // 3. Parallel Expansion Logic for Rounds 16..63
    // ------------------------------------------------------------------------
    // Round A word: W_t = sigma1(w[14]) + w[9] + sigma0(w[1]) + w[0]
    wire [31:0] s0_A = sigma0(w[1]);
    wire [31:0] s1_A = sigma1(w[14]);
    wire [31:0] w_new_A = s1_A + w[9] + s0_A + w[0];

    // Round B word: W_{t+1} = sigma1(w[15]) + w[10] + sigma0(w[2]) + w[1]
    wire [31:0] s0_B = sigma0(w[2]);
    wire [31:0] s1_B = sigma1(w[15]);
    wire [31:0] w_new_B = s1_B + w[10] + s0_B + w[1];

    // Combinational Outputs:
    // - Steps 0..7 (rounds 0..15): direct window words w[0] and w[1]
    // - Steps 8..31 (rounds 16..63): newly calculated words
    assign w_t        = (step < 5'd8) ? w[0] : w_new_A;
    assign w_t_plus_1 = (step < 5'd8) ? w[1] : w_new_B;

    wire [31:0] next_w14 = (step < 5'd8) ? w[0] : w_new_A;
    wire [31:0] next_w15 = (step < 5'd8) ? w[1] : w_new_B;

    // ------------------------------------------------------------------------
    // 4. Sequential 2-Word Shift Register Operation
    // ------------------------------------------------------------------------
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1) begin
                w[i] <= 32'd0;
            end
        end else if (load) begin
            // Big-endian unpacking of 512-bit block
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
            // Shift array by 2 positions
            for (i = 0; i < 14; i = i + 1) begin
                w[i] <= w[i+2];
            end
            w[14] <= next_w14;
            w[15] <= next_w15;
        end
    end

endmodule
