`timescale 1ns / 1ps

/**
 * ============================================================================
 * Module: sha256_datapath_8bit
 * Description: 8-Bit Folded Datapath for SHA-256 v6.0 Micro-Edge Architecture.
 *              Replaces all 32-bit Carry-Propagate Adders with 8-bit adders,
 *              serializing the compression round over 4 clock cycles per round.
 *              Uses internal shift registers to assemble the 32-bit A_next
 *              and E_next results byte-by-byte (LSB to MSB) with carry flip-flops.
 * Specification: docs/11_v6_micro_edge_architecture.md
 * Target: Low-Power Edge IoT / Coin-Cell Sensors (XC7Z020 FPGA)
 * ============================================================================
 */

module sha256_datapath_8bit (
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
    input  wire         step,          // Active during COMPRESS state
    input  wire [1:0]   sub_cycle,     // Byte index [0..3] within current 4-cycle round
    input  wire [7:0]   w_byte,        // 8-bit slice of current round message word
    input  wire [7:0]   k_byte,        // 8-bit slice of current round constant
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
    // Shift Registers for 8-bit Assembly over 4 Sub-Cycles
    // ------------------------------------------------------------------------
    reg [31:0] shift_a;
    reg [31:0] shift_e;

    // Carry Flip-Flops across Sub-Cycles
    reg [2:0] carry_t1;
    reg       carry_t2;
    reg       carry_a;
    reg       carry_e;

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
    wire [31:0] ch_val;
    assign ch_val = (e & f) ^ (~e & g);

    wire [31:0] maj_val;
    assign maj_val = (a & b) ^ (a & c) ^ (b & c);

    wire [31:0] big_sigma0_val;
    assign big_sigma0_val = rotr(a, 5'd2) ^ rotr(a, 5'd13) ^ rotr(a, 5'd22);

    wire [31:0] big_sigma1_val;
    assign big_sigma1_val = rotr(e, 5'd6) ^ rotr(e, 5'd11) ^ rotr(e, 5'd25);

    // ------------------------------------------------------------------------
    // 8-Bit Slicing of Operands based on sub_cycle [0..3]
    // ------------------------------------------------------------------------
    wire [7:0] h_slice;
    wire [7:0] d_slice;
    wire [7:0] sigma1_slice;
    wire [7:0] ch_slice;
    wire [7:0] sigma0_slice;
    wire [7:0] maj_slice;

    assign h_slice      = (sub_cycle == 2'd0) ? h[7:0]   :
                          (sub_cycle == 2'd1) ? h[15:8]  :
                          (sub_cycle == 2'd2) ? h[23:16] : h[31:24];

    assign d_slice      = (sub_cycle == 2'd0) ? d[7:0]   :
                          (sub_cycle == 2'd1) ? d[15:8]  :
                          (sub_cycle == 2'd2) ? d[23:16] : d[31:24];

    assign sigma1_slice = (sub_cycle == 2'd0) ? big_sigma1_val[7:0]   :
                          (sub_cycle == 2'd1) ? big_sigma1_val[15:8]  :
                          (sub_cycle == 2'd2) ? big_sigma1_val[23:16] : big_sigma1_val[31:24];

    assign ch_slice     = (sub_cycle == 2'd0) ? ch_val[7:0]   :
                          (sub_cycle == 2'd1) ? ch_val[15:8]  :
                          (sub_cycle == 2'd2) ? ch_val[23:16] : ch_val[31:24];

    assign sigma0_slice = (sub_cycle == 2'd0) ? big_sigma0_val[7:0]   :
                          (sub_cycle == 2'd1) ? big_sigma0_val[15:8]  :
                          (sub_cycle == 2'd2) ? big_sigma0_val[23:16] : big_sigma0_val[31:24];

    assign maj_slice    = (sub_cycle == 2'd0) ? maj_val[7:0]   :
                          (sub_cycle == 2'd1) ? maj_val[15:8]  :
                          (sub_cycle == 2'd2) ? maj_val[23:16] : maj_val[31:24];

    // Carry-in gating for byte 0
    wire [2:0] c_in_t1 = (sub_cycle == 2'd0) ? 3'd0 : carry_t1;
    wire       c_in_t2 = (sub_cycle == 2'd0) ? 1'b0 : carry_t2;
    wire       c_in_a  = (sub_cycle == 2'd0) ? 1'b0 : carry_a;
    wire       c_in_e  = (sub_cycle == 2'd0) ? 1'b0 : carry_e;

    // ------------------------------------------------------------------------
    // 8-Bit Adder Chains with Carry Out
    // ------------------------------------------------------------------------
    // 1. T1 8-bit sum: H_byte + Sigma1_byte + Ch_byte + K_byte + W_byte + carry
    wire [10:0] sum_t1_full;
    assign sum_t1_full = {3'b0, h_slice} + {3'b0, sigma1_slice} + {3'b0, ch_slice} +
                         {3'b0, k_byte}  + {3'b0, w_byte}        + {8'b0, c_in_t1};
    wire [7:0] t1_byte  = sum_t1_full[7:0];
    wire [2:0] c_out_t1 = sum_t1_full[10:8];

    // 2. T2 8-bit sum: Sigma0_byte + Maj_byte + carry
    wire [8:0] sum_t2_full;
    assign sum_t2_full = {1'b0, sigma0_slice} + {1'b0, maj_slice} + {8'b0, c_in_t2};
    wire [7:0] t2_byte  = sum_t2_full[7:0];
    wire       c_out_t2 = sum_t2_full[8];

    // 3. A_next 8-bit sum: T1_byte + T2_byte + carry
    wire [8:0] sum_a_full;
    assign sum_a_full = {1'b0, t1_byte} + {1'b0, t2_byte} + {8'b0, c_in_a};
    wire [7:0] a_byte  = sum_a_full[7:0];
    wire       c_out_a = sum_a_full[8];

    // 4. E_next 8-bit sum: D_byte + T1_byte + carry
    wire [8:0] sum_e_full;
    assign sum_e_full = {1'b0, d_slice} + {1'b0, t1_byte} + {8'b0, c_in_e};
    wire [7:0] e_byte  = sum_e_full[7:0];
    wire       c_out_e = sum_e_full[8];

    // Fully assembled 32-bit words at the conclusion of sub_cycle 3
    wire [31:0] a_next_full = {a_byte, shift_a[31:8]};
    wire [31:0] e_next_full = {e_byte, shift_e[31:8]};

    // ------------------------------------------------------------------------
    // Sequential State and Shift Register Update Logic
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            a        <= 32'd0;
            b        <= 32'd0;
            c        <= 32'd0;
            d        <= 32'd0;
            e        <= 32'd0;
            f        <= 32'd0;
            g        <= 32'd0;
            h        <= 32'd0;
            shift_a  <= 32'd0;
            shift_e  <= 32'd0;
            carry_t1 <= 3'd0;
            carry_t2 <= 1'b0;
            carry_a  <= 1'b0;
            carry_e  <= 1'b0;
        end else if (load_init) begin
            a        <= init_a;
            b        <= init_b;
            c        <= init_c;
            d        <= init_d;
            e        <= init_e;
            f        <= init_f;
            g        <= init_g;
            h        <= init_h;
            shift_a  <= 32'd0;
            shift_e  <= 32'd0;
            carry_t1 <= 3'd0;
            carry_t2 <= 1'b0;
            carry_a  <= 1'b0;
            carry_e  <= 1'b0;
        end else if (step) begin
            if (sub_cycle == 2'd3) begin
                // 4th cycle: commit the fully assembled 32-bit round results
                a        <= a_next_full;
                b        <= a;
                c        <= b;
                d        <= c;
                e        <= e_next_full;
                f        <= e;
                g        <= f;
                h        <= g;
                shift_a  <= 32'd0;
                shift_e  <= 32'd0;
                carry_t1 <= 3'd0;
                carry_t2 <= 1'b0;
                carry_a  <= 1'b0;
                carry_e  <= 1'b0;
            end else begin
                // Sub-cycles 0, 1, 2: shift byte into accumulator and register carries
                shift_a  <= {a_byte, shift_a[31:8]};
                shift_e  <= {e_byte, shift_e[31:8]};
                carry_t1 <= c_out_t1;
                carry_t2 <= c_out_t2;
                carry_a  <= c_out_a;
                carry_e  <= c_out_e;
            end
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

    // Concatenated 256-bit working state exposed for verification
    assign intermediate_state = {a, b, c, d, e, f, g, h};

endmodule
