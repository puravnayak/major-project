`timescale 1ns / 1ps

/**
 * ============================================================================
 * Module: sha256_w_schedule_8bit
 * Description: 8-Bit Sliced Message Scheduler for SHA-256 v6.0 Micro-Edge.
 *              Uses the 16-word sliding window from v2, but streams out 8-bit
 *              slices of W_t based on the sub-cycle index [0..3].
 *              The 16-word shift register advances only once every 4 cycles
 *              (on sub_cycle == 3) at the completion of each compression round.
 * Specification: docs/11_v6_micro_edge_architecture.md
 * ============================================================================
 */

module sha256_w_schedule_8bit (
    input  wire         clk,
    input  wire         rst,
    input  wire         enable,      // Active during COMPRESS state
    input  wire         load,        // Active during INIT state
    input  wire [1:0]   sub_cycle,   // Byte index [0..3]
    input  wire [511:0] block_in,    // 512-bit padded message block
    input  wire [5:0]   round,       // Current round index [0..63]
    output wire [7:0]   w_byte       // Selected 8-bit slice of current W_t
);

    // ------------------------------------------------------------------------
    // 1. SHA-256 Bitwise Transformation Functions
    // ------------------------------------------------------------------------
    function [31:0] rotr;
        input [31:0] x;
        input [4:0]  n;
        begin
            rotr = (x >> n) | (x << (32 - n));
        end
    endfunction

    function [31:0] sigma0;
        input [31:0] x;
        begin
            sigma0 = rotr(x, 5'd7) ^ rotr(x, 5'd18) ^ (x >> 3);
        end
    endfunction

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
    wire [31:0] s0;
    wire [31:0] s1;
    wire [31:0] w_new;

    assign s0    = sigma0(w[1]);
    assign s1    = sigma1(w[14]);
    assign w_new = s1 + w[9] + s0 + w[0];

    // Full 32-bit selected W_t word
    wire [31:0] w_full;
    assign w_full = (round < 6'd16) ? w[0] : w_new;

    // 8-bit slice output (LSB first: sub_cycle 0 -> [7:0], 1 -> [15:8], etc.)
    assign w_byte = (sub_cycle == 2'd0) ? w_full[7:0]   :
                    (sub_cycle == 2'd1) ? w_full[15:8]  :
                    (sub_cycle == 2'd2) ? w_full[23:16] : w_full[31:24];

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
        end else if (enable && (sub_cycle == 2'd3)) begin
            // Shift array once at the end of each 4-cycle round
            for (i = 0; i < 15; i = i + 1) begin
                w[i] <= w[i+1];
            end
            w[15] <= (round < 6'd16) ? w[0] : w_new;
        end
    end

endmodule
