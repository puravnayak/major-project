`timescale 1ns / 1ps

/**
 * ============================================================================
 * Module: sha256_top
 * Description: Top-level wrapper and FSM controller for SHA-256 v3.0 High-Throughput
 *              Architecture. Executes 2 rounds per clock cycle using unrolled
 *              datapath and Carry-Save Adders (CSAs), reducing execution time
 *              from 64 compression cycles down to 32 cycles.
 * Specification: docs/08_v3_throughput_architecture.md
 * Target: Vivado RTL Synthesis / FPGA Prototyping
 * ============================================================================
 */

module sha256_top (
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

    // Internal Step Counter [0..31] (32 steps for 64 rounds)
    reg [4:0] step_cnt;
    reg [5:0] round_out_reg;

    // Datapath Interface Wires
    wire [31:0] k_t_cur, k_t_plus_1_cur;
    wire [31:0] w_t_cur, w_t_plus_1_cur;
    wire [31:0] a_cur, b_cur, c_cur, d_cur, e_cur, f_cur, g_cur, h_cur;

    // FSM Control Signals
    reg w_load;
    reg w_enable;
    reg load_datapath;
    reg step_datapath;
    reg update_hash;
    reg fsm_valid_out;

    // ------------------------------------------------------------------------
    // FSM Block 1: State Register (Synchronous active-high reset)
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
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
                // 32 cycles total (step_cnt 0 to 31)
                if (step_cnt == 5'd31)
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
    // FSM Block 3: Output & Datapath Control Logic
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
                // Idle
            end

            STATE_INIT: begin
                w_load        = 1'b1;  // Load block into message scheduler
                load_datapath = 1'b1;  // Load H0-H7 into working variables
            end

            STATE_COMPRESS: begin
                w_enable      = 1'b1;  // Advance unrolled sliding window by 2 words
                step_datapath = 1'b1;  // Advance unrolled datapath by 2 rounds
            end

            STATE_UPDATE: begin
                update_hash   = 1'b1;  // Add final working variables to H0-H7
            end

            STATE_DONE: begin
                fsm_valid_out = 1'b1;  // Signal final hash ready
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
    // Sequential State & Counter Updates
    // ------------------------------------------------------------------------
    reg [511:0] block_reg;

    always @(posedge clk) begin
        if (rst) begin
            block_reg     <= 512'd0;
            step_cnt      <= 5'd0;
            round_out_reg <= 6'h3F;
            h0            <= H0_INIT;
            h1            <= H1_INIT;
            h2            <= H2_INIT;
            h3            <= H3_INIT;
            h4            <= H4_INIT;
            h5            <= H5_INIT;
            h6            <= H6_INIT;
            h7            <= H7_INIT;
        end else begin
            if (valid_in) begin
                block_reg <= block_in; // Latch input block
            end

            case (current_state)
                STATE_IDLE: begin
                    step_cnt      <= 5'd0;
                    round_out_reg <= 6'h3F;
                end

                STATE_INIT: begin
                    step_cnt      <= 5'd0;
                    round_out_reg <= 6'h3F;
                end

                STATE_COMPRESS: begin
                    // Expose the completed round index at every 2 rounds
                    round_out_reg <= {step_cnt, 1'b1}; // Represents round 2*step + 1 (1, 3, 5, ..., 63)
                    if (step_cnt < 5'd31) begin
                        step_cnt <= step_cnt + 5'd1;
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
                    step_cnt      <= 5'd0;
                    round_out_reg <= 6'h3F;
                end
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // Submodule Instantiations
    // ------------------------------------------------------------------------

    // 1. Dual-Constant K ROM (Lookup table)
    sha256_k_rom_unrolled u_k_rom (
        .step       (step_cnt),
        .k_t        (k_t_cur),
        .k_t_plus_1 (k_t_plus_1_cur),
        .k_out      ()
    );

    // 2. Dual-Word Message Scheduler (16-word sliding window shifted by 2)
    sha256_w_schedule_unrolled u_w_schedule (
        .clk        (clk),
        .rst        (rst),
        .enable     (w_enable),
        .load       (w_load),
        .block_in   (block_reg),
        .step       (step_cnt),
        .w_t        (w_t_cur),
        .w_t_plus_1 (w_t_plus_1_cur)
    );

    // 3. 2x Unrolled Datapath with CSAs
    sha256_datapath_unrolled u_datapath (
        .clk                        (clk),
        .rst                        (rst),
        .load_init                  (load_datapath),
        .init_a                     (h0),
        .init_b                     (h1),
        .init_c                     (h2),
        .init_d                     (h3),
        .init_e                     (h4),
        .init_f                     (h5),
        .init_g                     (h6),
        .init_h                     (h7),
        .step                       (step_datapath),
        .w_t                        (w_t_cur),
        .w_t_plus_1                 (w_t_plus_1_cur),
        .k_t                        (k_t_cur),
        .k_t_plus_1                 (k_t_plus_1_cur),
        .a_out                      (a_cur),
        .b_out                      (b_cur),
        .c_out                      (c_cur),
        .d_out                      (d_cur),
        .e_out                      (e_cur),
        .f_out                      (f_cur),
        .g_out                      (g_cur),
        .h_out                      (h_cur),
        .intermediate_state         (intermediate_state_out),
        .intermediate_state_round_a ()
    );

    // ------------------------------------------------------------------------
    // Top-Level Output Assignments
    // ------------------------------------------------------------------------
    assign round_out  = round_out_reg;
    assign hash_out   = {h0, h1, h2, h3, h4, h5, h6, h7};
    assign valid_out  = fsm_valid_out;

endmodule

// ----------------------------------------------------------------------------
// Drop-in wrapper alias for testbenches referencing sha256_core
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
    sha256_top u_top (
        .clk                   (clk),
        .rst                   (rst),
        .valid_in              (valid_in),
        .block_in              (block_in),
        .round_out             (round_out),
        .intermediate_state_out(intermediate_state_out),
        .hash_out              (hash_out),
        .valid_out             (valid_out)
    );
endmodule
