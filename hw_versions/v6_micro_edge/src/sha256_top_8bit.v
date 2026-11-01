`timescale 1ns / 1ps

/**
 * ============================================================================
 * Module: sha256_top_8bit
 * Description: Top-level wrapper and FSM controller for SHA-256 v6.0 Micro-Edge
 *              Architecture with an 8-bit folded datapath.
 *              The COMPRESS state executes across 256 clock cycles (64 rounds
 *              x 4 sub-cycles per round) to achieve minimal area and power.
 * Specification: docs/11_v6_micro_edge_architecture.md
 * Target: Low-Power Edge IoT / Coin-Cell Sensors (XC7Z020 FPGA)
 * ============================================================================
 */

module sha256_top_8bit (
    input  wire         clk,
    input  wire         rst,
    input  wire         valid_in,
    input  wire [511:0] block_in,
    output wire [5:0]   round_out,
    output wire [255:0] intermediate_state_out,
    output wire [255:0] hash_out,
    output wire         valid_out
);

    // ------------------------------------------------------------------------
    // FSM State Encoding
    // ------------------------------------------------------------------------
    localparam [2:0] STATE_IDLE     = 3'd0,
                     STATE_INIT     = 3'd1,
                     STATE_COMPRESS = 3'd2,
                     STATE_UPDATE   = 3'd3,
                     STATE_DONE     = 3'd4;

    reg [2:0] current_state, next_state;

    // ------------------------------------------------------------------------
    // SHA-256 Initial Constants (FIPS 180-4 Section 5.3.3)
    // ------------------------------------------------------------------------
    localparam [31:0] H0_INIT = 32'h6a09e667,
                      H1_INIT = 32'hbb67ae85,
                      H2_INIT = 32'h3c6ef372,
                      H3_INIT = 32'ha54ff53a,
                      H4_INIT = 32'h510e527f,
                      H5_INIT = 32'h9b05688c,
                      H6_INIT = 32'h1f83d9ab,
                      H7_INIT = 32'h5be0cd19;

    // Accumulated Hash Registers (H0-H7)
    reg [31:0] h0, h1, h2, h3, h4, h5, h6, h7;

    // 8-bit Folded Compression Counters:
    // cycle_cnt [0..255] -> round_cnt [0..63] = cycle_cnt[7:2]
    //                    -> sub_cycle [0..3]  = cycle_cnt[1:0]
    reg [7:0] cycle_cnt;
    wire [5:0] round_cnt = cycle_cnt[7:2];
    wire [1:0] sub_cycle = cycle_cnt[1:0];

    reg [5:0] round_out_reg;

    // Submodule Interface Signals
    wire [7:0]  k_byte_cur;
    wire [7:0]  w_byte_cur;
    wire [31:0] a_cur, b_cur, c_cur, d_cur, e_cur, f_cur, g_cur, h_cur;

    // FSM Control Signals
    reg w_load;
    reg w_enable;
    reg load_datapath;
    reg step_datapath;
    reg update_hash;
    reg fsm_valid_out;

    // Padded Input Block Register
    reg [511:0] block_reg;

    // ------------------------------------------------------------------------
    // FSM Block 1: State Register & Reset Logic
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // ------------------------------------------------------------------------
    // FSM Block 2: Next-State Combinational Logic
    // ------------------------------------------------------------------------
    always @(*) begin
        case (current_state)
            STATE_IDLE: begin
                if (valid_in)
                    next_state = STATE_INIT;
                else
                    next_state = STATE_IDLE;
            end

            STATE_INIT: begin
                next_state = STATE_COMPRESS;
            end

            STATE_COMPRESS: begin
                // Loops exactly 256 times (64 rounds x 4 cycles/round)
                if (cycle_cnt == 8'd255)
                    next_state = STATE_UPDATE;
                else
                    next_state = STATE_COMPRESS;
            end

            STATE_UPDATE: begin
                next_state = STATE_DONE;
            end

            STATE_DONE: begin
                next_state = STATE_IDLE;
            end

            default: next_state = STATE_IDLE;
        endcase
    end

    // ------------------------------------------------------------------------
    // FSM Block 3: Output & Control Logic
    // ------------------------------------------------------------------------
    always @(*) begin
        w_load        = 1'b0;
        w_enable      = 1'b0;
        load_datapath = 1'b0;
        step_datapath = 1'b0;
        update_hash   = 1'b0;
        fsm_valid_out = 1'b0;

        case (current_state)
            STATE_IDLE: begin
                // Idle waiting for input
            end

            STATE_INIT: begin
                w_load        = 1'b1;  // Load block into message scheduler
                load_datapath = 1'b1;  // Load H0-H7 into working variables
            end

            STATE_COMPRESS: begin
                w_enable      = 1'b1;  // Enable message scheduler (shifts on sub_cycle 3)
                step_datapath = 1'b1;  // Advance 8-bit folded datapath
            end

            STATE_UPDATE: begin
                update_hash   = 1'b1;  // Accumulate working variables into H0-H7
            end

            STATE_DONE: begin
                fsm_valid_out = 1'b1;  // Output valid pulse
            end

            default: begin
                w_load        = 1'b0;
                w_enable      = 1'b0;
                load_datapath = 1'b0;
                step_datapath = 1'b0;
                update_hash   = 1'b0;
                fsm_valid_out = 1'b0;
            end
        endcase
    end

    // ------------------------------------------------------------------------
    // Sequential State and Datapath Control Updates
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            h0            <= H0_INIT;
            h1            <= H1_INIT;
            h2            <= H2_INIT;
            h3            <= H3_INIT;
            h4            <= H4_INIT;
            h5            <= H5_INIT;
            h6            <= H6_INIT;
            h7            <= H7_INIT;
            cycle_cnt     <= 8'd0;
            round_out_reg <= 6'h3F;
            block_reg     <= 512'd0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    cycle_cnt     <= 8'd0;
                    round_out_reg <= 6'h3F;
                    if (valid_in) begin
                        block_reg <= block_in;
                    end
                end

                STATE_INIT: begin
                    cycle_cnt     <= 8'd0;
                    round_out_reg <= 6'h3F;
                end

                STATE_COMPRESS: begin
                    round_out_reg <= round_cnt;
                    if (cycle_cnt == 8'd255) begin
                        cycle_cnt <= 8'd0;
                    end else begin
                        cycle_cnt <= cycle_cnt + 8'd1;
                    end
                end

                STATE_UPDATE: begin
                    round_out_reg <= 6'h3F;
                    h0 <= h0 + a_cur;
                    h1 <= h1 + b_cur;
                    h2 <= h2 + c_cur;
                    h3 <= h3 + d_cur;
                    h4 <= h4 + e_cur;
                    h5 <= h5 + f_cur;
                    h6 <= h6 + g_cur;
                    h7 <= h7 + h_cur;
                end

                STATE_DONE: begin
                    round_out_reg <= 6'h3F;
                end

                default: begin
                    cycle_cnt     <= 8'd0;
                    round_out_reg <= 6'h3F;
                end
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // Submodule Instantiations
    // ------------------------------------------------------------------------

    // 1. 8-Bit Sliced K Constants ROM
    sha256_k_rom_8bit u_k_rom (
        .round     (round_cnt),
        .sub_cycle (sub_cycle),
        .k_byte    (k_byte_cur)
    );

    // 2. 8-Bit Sliced 16-Word Sliding Window Message Scheduler
    sha256_w_schedule_8bit u_w_schedule (
        .clk       (clk),
        .rst       (rst),
        .enable    (w_enable),
        .load      (w_load),
        .sub_cycle (sub_cycle),
        .block_in  (block_reg),
        .round     (round_cnt),
        .w_byte    (w_byte_cur)
    );

    // 3. 8-Bit Folded Compression Datapath
    sha256_datapath_8bit u_datapath (
        .clk                (clk),
        .rst                (rst),
        .load_init          (load_datapath),
        .init_a             (h0),
        .init_b             (h1),
        .init_c             (h2),
        .init_d             (h3),
        .init_e             (h4),
        .init_f             (h5),
        .init_g             (h6),
        .init_h             (h7),
        .step               (step_datapath),
        .sub_cycle          (sub_cycle),
        .w_byte             (w_byte_cur),
        .k_byte             (k_byte_cur),
        .a_out              (a_cur),
        .b_out              (b_cur),
        .c_out              (c_cur),
        .d_out              (d_cur),
        .e_out              (e_cur),
        .f_out              (f_cur),
        .g_out              (g_cur),
        .h_out              (h_cur),
        .intermediate_state (intermediate_state_out)
    );

    // ------------------------------------------------------------------------
    // Top-Level Output Assignments
    // ------------------------------------------------------------------------
    assign round_out  = round_out_reg;
    assign hash_out   = {h0, h1, h2, h3, h4, h5, h6, h7};
    assign valid_out  = fsm_valid_out;

endmodule

// ----------------------------------------------------------------------------
// Drop-in alias wrapper for sha256_top / sha256_core compatibility
// ----------------------------------------------------------------------------
module sha256_core (
    input  wire         clk,
    input  wire         rst,
    input  wire         valid_in,
    input  wire [511:0] block_in,
    output wire [5:0]   round_out,
    output wire [255:0] intermediate_state_out,
    output wire [255:0] hash_out,
    output wire         valid_out
);
    sha256_top_8bit u_top (
        .clk                    (clk),
        .rst                    (rst),
        .valid_in               (valid_in),
        .block_in               (block_in),
        .round_out              (round_out),
        .intermediate_state_out (intermediate_state_out),
        .hash_out               (hash_out),
        .valid_out              (valid_out)
    );
endmodule
