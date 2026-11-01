`timescale 1ns / 1ps

/**
 * ============================================================================
 * Module: sha256_top
 * Description: Top-level wrapper and FSM controller for SHA-256 v2.0 IoT Edge
 *              Accelerator architecture.
 * Specification: docs/07_v2_iot_architecture.md
 * Target: Vivado RTL Synthesis / FPGA Prototyping
 *
 * Architecture:
 * - 3-Block FSM style:
 *     Block 1: State Register (Synchronous active-high reset)
 *     Block 2: Next-State Combinational Logic
 *     Block 3: Output & Control Logic (w_load during INIT, w_enable during COMPRESS)
 * - Instantiates sha256_k_rom, sha256_w_schedule (16-word sliding window),
 *   and sha256_datapath.
 * - Manages H0-H7 hash accumulation registers across message blocks.
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
    // FSM State Encoding (3-bit parameter)
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

    // Internal Counters & Registers
    reg [5:0] round_cnt;
    reg [5:0] round_out_reg;

    // Datapath Interface Wires
    wire [31:0] k_cur;
    wire [31:0] w_cur;
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
                if (round_cnt == 6'd63)
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
        // Default control signal assignments
        w_load        = 1'b0;
        w_enable      = 1'b0;
        load_datapath = 1'b0;
        step_datapath = 1'b0;
        update_hash   = 1'b0;
        fsm_valid_out = 1'b0;

        case (current_state)
            STATE_IDLE: begin
                // Waiting for valid_in
            end

            STATE_INIT: begin
                w_load        = 1'b1;  // Load block into message scheduler (INIT only)
                load_datapath = 1'b1;  // Load current H0-H7 into working variables
            end

            STATE_COMPRESS: begin
                w_enable      = 1'b1;  // Step on-the-fly sliding window scheduler (COMPRESS only)
                step_datapath = 1'b1;  // Advance datapath compression round
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
            round_cnt     <= 6'd0;
            round_out_reg <= 6'h3F; // Indicate out-of-band / idle to testbench
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
                    round_cnt     <= 6'd0;
                    round_out_reg <= 6'h3F;
                end

                STATE_INIT: begin
                    round_cnt     <= 6'd0;
                    round_out_reg <= 6'h3F;
                end

                STATE_COMPRESS: begin
                    round_out_reg <= round_cnt;
                    if (round_cnt < 6'd63) begin
                        round_cnt <= round_cnt + 6'd1;
                    end
                end

                STATE_UPDATE: begin
                    round_out_reg <= 6'h3F;
                    // Add accumulated hash values according to FIPS 180-4 Section 6.2.2
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
                    round_cnt     <= 6'd0;
                    round_out_reg <= 6'h3F;
                end
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // Submodule Instantiations
    // ------------------------------------------------------------------------

    // 1. K Constants ROM (Lookup table)
    sha256_k_rom u_k_rom (
        .round (round_cnt),
        .k_out (k_cur)
    );

    // 2. Message Scheduler (16-word on-the-fly sliding window scheduler)
    sha256_w_schedule u_w_schedule (
        .clk      (clk),
        .rst      (rst),
        .enable   (w_enable),
        .load     (w_load),
        .block_in (block_reg),
        .round    (round_cnt),
        .w_out    (w_cur)
    );

    // 3. Datapath (Working variables and round compression logic)
    sha256_datapath u_datapath (
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
        .w_t                (w_cur),
        .k_t                (k_cur),
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
