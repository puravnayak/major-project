`timescale 1ns / 1ps

/**
 * ============================================================================
 * Module: sha256_w_schedule
 * Description: Message Scheduler for SHA-256 v1.0 Baseline Architecture.
 *              Unpacks 512-bit block into 16 initial 32-bit words and expands
 *              them into 64 words (W_0 to W_63) using a 64-word register array.
 * Architecture: v1.0 Baseline (64-entry register array loaded in INIT state)
 * ============================================================================
 */

module sha256_w_schedule (
    input  wire         clk,
    input  wire         rst,
    input  wire         load,        // Asserted in INIT state to load and expand
    input  wire [511:0] block_in,    // 512-bit padded message block
    input  wire [5:0]   round,       // Current round index [0..63]
    output wire [31:0]  w_out        // Selected W_t word for the active round
);

    // ------------------------------------------------------------------------
    // Bitwise Transformation Functions
    // ------------------------------------------------------------------------
    function [31:0] rotr;
        input [31:0] x;
        input [4:0]  n;
        begin
            rotr = (x >> n) | (x << (32 - n));
        end
    endfunction

    // sigma0(x) = ROTR^7(x) ^ ROTR^18(x) ^ SHR^3(x)
    function [31:0] small_sigma0;
        input [31:0] x;
        begin
            small_sigma0 = rotr(x, 5'd7) ^ rotr(x, 5'd18) ^ (x >> 3);
        end
    endfunction

    // sigma1(x) = ROTR^17(x) ^ ROTR^19(x) ^ SHR^10(x)
    function [31:0] small_sigma1;
        input [31:0] x;
        begin
            small_sigma1 = rotr(x, 5'd17) ^ rotr(x, 5'd19) ^ (x >> 10);
        end
    endfunction

    // ------------------------------------------------------------------------
    // Message Expansion Logic
    // ------------------------------------------------------------------------
    // Combinational expansion of all 64 words from block_in
    reg [31:0] w_comb [0:63];
    integer j;

    always @(*) begin
        // First 16 words are extracted directly from 512-bit block (Big-Endian)
        for (j = 0; j < 16; j = j + 1) begin
            w_comb[j] = block_in[(15 - j) * 32 +: 32];
        end

        // Expansion for words 16 to 63:
        // W_t = sigma1(W_{t-2}) + W_{t-7} + sigma0(W_{t-15}) + W_{t-16}
        for (j = 16; j < 64; j = j + 1) begin
            w_comb[j] = small_sigma1(w_comb[j - 2]) +
                        w_comb[j - 7] +
                        small_sigma0(w_comb[j - 15]) +
                        w_comb[j - 16];
        end
    end

    // ------------------------------------------------------------------------
    // 64-Word Register Array Storage (v1.0 Architecture)
    // ------------------------------------------------------------------------
    reg [31:0] w_mem [0:63];
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 64; i = i + 1) begin
                w_mem[i] <= 32'd0;
            end
        end else if (load) begin
            for (i = 0; i < 64; i = i + 1) begin
                w_mem[i] <= w_comb[i];
            end
        end
    end

    // Output selected word based on round counter
    assign w_out = w_mem[round];

endmodule
