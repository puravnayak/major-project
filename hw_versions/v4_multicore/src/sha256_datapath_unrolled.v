`timescale 1ns / 1ps

/**
 * ============================================================================
 * Module: csa_32
 * Description: 32-bit Carry-Save Adder (3:2 compressor).
 *              Given three 32-bit inputs X, Y, Z, computes sum and carry vectors
 *              such that (X + Y + Z) mod 2^32 = (sum + (carry << 1)) mod 2^32.
 * ============================================================================
 */
module csa_32 (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [31:0] c,
    output wire [31:0] sum,
    output wire [31:0] carry
);
    assign sum   = a ^ b ^ c;
    assign carry = (a & b) | (b & c) | (c & a);
endmodule

/**
 * ============================================================================
 * Module: sha256_datapath_unrolled
 * Description: 2x Loop-Unrolled Datapath with Carry-Save Adders (CSAs) for SHA-256 v3.0.
 *              Executes two compression rounds (Round A and Round B) combinationally
 *              within a single clock cycle. Uses 5:2 CSA compressor trees to compute
 *              T1 in each round without carry-propagation delay.
 * Specification: docs/08_v3_throughput_architecture.md
 * ============================================================================
 */
module sha256_datapath_unrolled (
    input  wire         clk,
    input  wire         rst,
    input  wire         load_init,     // Load initial H0-H7 into working registers
    input  wire [31:0]  init_a,
    input  wire [31:0]  init_b,
    input  wire [31:0]  init_c,
    input  wire [31:0]  init_d,
    input  wire [31:0]  init_e,
    input  wire [31:0]  init_f,
    input  wire [31:0]  init_g,
    input  wire [31:0]  init_h,
    input  wire         step,          // Advance working registers by 2 rounds
    input  wire [31:0]  w_t,           // Message word for Round A
    input  wire [31:0]  w_t_plus_1,    // Message word for Round B
    input  wire [31:0]  k_t,           // Constant for Round A
    input  wire [31:0]  k_t_plus_1,    // Constant for Round B
    output wire [31:0]  a_out,
    output wire [31:0]  b_out,
    output wire [31:0]  c_out,
    output wire [31:0]  d_out,
    output wire [31:0]  e_out,
    output wire [31:0]  f_out,
    output wire [31:0]  g_out,
    output wire [31:0]  h_out,
    output wire [255:0] intermediate_state,         // State after Round B (cycle end)
    output wire [255:0] intermediate_state_round_a  // State after Round A (mid-cycle)
);

    // ------------------------------------------------------------------------
    // Working State Registers (A through H)
    // ------------------------------------------------------------------------
    reg [31:0] a, b, c, d, e, f, g, h;

    assign a_out = a;
    assign b_out = b;
    assign c_out = c;
    assign d_out = d;
    assign e_out = e;
    assign f_out = f;
    assign g_out = g;
    assign h_out = h;
    assign intermediate_state = {a, b, c, d, e, f, g, h};

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

    // Ch(e, f, g) = (e & f) ^ (~e & g)
    function [31:0] ch;
        input [31:0] x, y, z;
        begin
            ch = (x & y) ^ (~x & z);
        end
    endfunction

    // Maj(a, b, c) = (a & b) ^ (a & c) ^ (b & c)
    function [31:0] maj;
        input [31:0] x, y, z;
        begin
            maj = (x & y) ^ (x & z) ^ (y & z);
        end
    endfunction

    // Sigma0(a) = ROTR^2(a) ^ ROTR^13(a) ^ ROTR^22(a)
    function [31:0] big_sigma0;
        input [31:0] x;
        begin
            big_sigma0 = rotr(x, 5'd2) ^ rotr(x, 5'd13) ^ rotr(x, 5'd22);
        end
    endfunction

    // Sigma1(e) = ROTR^6(e) ^ ROTR^11(e) ^ ROTR^25(e)
    function [31:0] big_sigma1;
        input [31:0] x;
        begin
            big_sigma1 = rotr(x, 5'd6) ^ rotr(x, 5'd11) ^ rotr(x, 5'd25);
        end
    endfunction

    // ========================================================================
    // UNROLLED ROUND A: Evaluates from registers {a, b, c, d, e, f, g, h}
    // ========================================================================
    wire [31:0] sigma1_A = big_sigma1(e);
    wire [31:0] ch_A     = ch(e, f, g);
    wire [31:0] sigma0_A = big_sigma0(a);
    wire [31:0] maj_A    = maj(a, b, c);

    // 5:2 Carry-Save Adder Tree for T1_A = h + Sigma1(e) + Ch(e,f,g) + k_t + w_t
    wire [31:0] s1A, c1A;
    wire [31:0] s2A, c2A;
    wire [31:0] s3A, c3A;

    csa_32 u_csa1_A (
        .a     (h),
        .b     (sigma1_A),
        .c     (ch_A),
        .sum   (s1A),
        .carry (c1A)
    );

    csa_32 u_csa2_A (
        .a     (s1A),
        .b     ({c1A[30:0], 1'b0}),
        .c     (k_t),
        .sum   (s2A),
        .carry (c2A)
    );

    csa_32 u_csa3_A (
        .a     (s2A),
        .b     ({c2A[30:0], 1'b0}),
        .c     (w_t),
        .sum   (s3A),
        .carry (c3A)
    );

    // Resolve T1_A and T2_A
    wire [31:0] t1_A = s3A + {c3A[30:0], 1'b0};
    wire [31:0] t2_A = sigma0_A + maj_A;

    // Intermediate working variables after Round A
    wire [31:0] a_next_A = t1_A + t2_A;
    wire [31:0] b_next_A = a;
    wire [31:0] c_next_A = b;
    wire [31:0] d_next_A = c;
    wire [31:0] e_next_A = d + t1_A;
    wire [31:0] f_next_A = e;
    wire [31:0] g_next_A = f;
    wire [31:0] h_next_A = g;

    assign intermediate_state_round_a = {a_next_A, b_next_A, c_next_A, d_next_A,
                                         e_next_A, f_next_A, g_next_A, h_next_A};

    // ========================================================================
    // UNROLLED ROUND B: Evaluates from Round A intermediate values
    // ========================================================================
    wire [31:0] sigma1_B = big_sigma1(e_next_A);
    wire [31:0] ch_B     = ch(e_next_A, f_next_A, g_next_A);
    wire [31:0] sigma0_B = big_sigma0(a_next_A);
    wire [31:0] maj_B    = maj(a_next_A, b_next_A, c_next_A);

    // 5:2 Carry-Save Adder Tree for T1_B = h_next_A + Sigma1(e_next_A) + Ch(e_next_A,f_next_A,g_next_A) + k_t_plus_1 + w_t_plus_1
    wire [31:0] s1B, c1B;
    wire [31:0] s2B, c2B;
    wire [31:0] s3B, c3B;

    csa_32 u_csa1_B (
        .a     (h_next_A),
        .b     (sigma1_B),
        .c     (ch_B),
        .sum   (s1B),
        .carry (c1B)
    );

    csa_32 u_csa2_B (
        .a     (s1B),
        .b     ({c1B[30:0], 1'b0}),
        .c     (k_t_plus_1),
        .sum   (s2B),
        .carry (c2B)
    );

    csa_32 u_csa3_B (
        .a     (s2B),
        .b     ({c2B[30:0], 1'b0}),
        .c     (w_t_plus_1),
        .sum   (s3B),
        .carry (c3B)
    );

    // Resolve T1_B and T2_B
    wire [31:0] t1_B = s3B + {c3B[30:0], 1'b0};
    wire [31:0] t2_B = sigma0_B + maj_B;

    // Final working variables at the end of the unrolled cycle
    wire [31:0] a_next_B = t1_B + t2_B;
    wire [31:0] b_next_B = a_next_A;
    wire [31:0] c_next_B = b_next_A;
    wire [31:0] d_next_B = c_next_A;
    wire [31:0] e_next_B = d_next_A + t1_B;
    wire [31:0] f_next_B = e_next_A;
    wire [31:0] g_next_B = f_next_A;
    wire [31:0] h_next_B = g_next_A;

    // ------------------------------------------------------------------------
    // Sequential State Register Update
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
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
            a <= a_next_B;
            b <= b_next_B;
            c <= c_next_B;
            d <= d_next_B;
            e <= e_next_B;
            f <= f_next_B;
            g <= g_next_B;
            h <= h_next_B;
        end
    end

endmodule
