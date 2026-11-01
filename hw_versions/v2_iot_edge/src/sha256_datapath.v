`timescale 1ns / 1ps

/**
 * ============================================================================
 * Module: sha256_datapath
 * Description: Working register datapath and single-round compression logic
 *              for SHA-256 v1.0 Baseline Architecture.
 *              Uses standard behavioral adders (+) for modular additions.
 * Architecture: v1.0 Baseline
 * ============================================================================
 */

module sha256_datapath (
    input  wire         clk,
    input  wire         rst,
    input  wire         load_init,     // Load working variables with initial/accumulated hash
    input  wire [31:0]  init_a,
    input  wire [31:0]  init_b,
    input  wire [31:0]  init_c,
    input  wire [31:0]  init_d,
    input  wire [31:0]  init_e,
    input  wire [31:0]  init_f,
    input  wire [31:0]  init_g,
    input  wire [31:0]  init_h,
    input  wire         step,          // Clock enable for compression round update
    input  wire [31:0]  w_t,           // Current round message word
    input  wire [31:0]  k_t,           // Current round constant
    output wire [31:0]  a_out,
    output wire [31:0]  b_out,
    output wire [31:0]  c_out,
    output wire [31:0]  d_out,
    output wire [31:0]  e_out,
    output wire [31:0]  f_out,
    output wire [31:0]  g_out,
    output wire [31:0]  h_out,
    output wire [255:0] intermediate_state
);

    // ------------------------------------------------------------------------
    // Working Registers (A, B, C, D, E, F, G, H)
    // ------------------------------------------------------------------------
    reg [31:0] a, b, c, d, e, f, g, h;

    // ------------------------------------------------------------------------
    // Bitwise Rotation Helper Function
    // ------------------------------------------------------------------------
    function [31:0] rotr;
        input [31:0] x;
        input [4:0]  n;
        begin
            rotr = (x >> n) | (x << (32 - n));
        end
    endfunction

    // ------------------------------------------------------------------------
    // Core SHA-256 Logical Functions
    // ------------------------------------------------------------------------
    // Ch(E, F, G) = (E & F) ^ (~E & G)
    wire [31:0] ch_val;
    assign ch_val = (e & f) ^ (~e & g);

    // Maj(A, B, C) = (A & B) ^ (A & C) ^ (B & C)
    wire [31:0] maj_val;
    assign maj_val = (a & b) ^ (a & c) ^ (b & c);

    // Sigma0(A) = ROTR^2(A) ^ ROTR^13(A) ^ ROTR^22(A)
    wire [31:0] big_sigma0_val;
    assign big_sigma0_val = rotr(a, 5'd2) ^ rotr(a, 5'd13) ^ rotr(a, 5'd22);

    // Sigma1(E) = ROTR^6(E) ^ ROTR^11(E) ^ ROTR^25(E)
    wire [31:0] big_sigma1_val;
    assign big_sigma1_val = rotr(e, 5'd6) ^ rotr(e, 5'd11) ^ rotr(e, 5'd25);

    // ------------------------------------------------------------------------
    // Standard Behavioral Adders (+) for Modular Addition (mod 2^32)
    // Establishing baseline area and critical path
    // ------------------------------------------------------------------------
    wire [31:0] t1;
    wire [31:0] t2;

    assign t1 = h + big_sigma1_val + ch_val + k_t + w_t;
    assign t2 = big_sigma0_val + maj_val;

    // Next-state values for the working variables
    wire [31:0] a_next = t1 + t2;
    wire [31:0] b_next = a;
    wire [31:0] c_next = b;
    wire [31:0] d_next = c;
    wire [31:0] e_next = d + t1;
    wire [31:0] f_next = e;
    wire [31:0] g_next = f;
    wire [31:0] h_next = g;

    // ------------------------------------------------------------------------
    // Working Registers Sequential Update
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            a <= 32'd0;
            b <= 32'd0;
            c <= 32'd0;
            d <= 32'd0;
            e <= 32'd0;
            f <= 32'd0;
            g <= 32'd0;
            h <= 32'd0;
        end else if (load_init) begin
            a <= init_a;
            b <= init_b;
            c <= init_c;
            d <= init_d;
            e <= init_e;
            f <= init_f;
            g <= init_g;
            h <= init_h;
        end else if (step) begin
            a <= a_next;
            b <= b_next;
            c <= c_next;
            d <= d_next;
            e <= e_next;
            f <= f_next;
            g <= g_next;
            h <= h_next;
        end
    end

    // ------------------------------------------------------------------------
    // Output Assignments
    // ------------------------------------------------------------------------
    assign a_out = a;
    assign b_out = b;
    assign c_out = c;
    assign d_out = d;
    assign e_out = e;
    assign f_out = f;
    assign g_out = g;
    assign h_out = h;

    // Concatenated 256-bit working state exposed for testbench cycle-by-cycle assertions
    assign intermediate_state = {a, b, c, d, e, f, g, h};

endmodule
