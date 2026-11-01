`timescale 1ns / 1ps

/**
 * ============================================================================
 * Module: sha256_k_rom_unrolled
 * Description: Dual-Constant K ROM for SHA-256 v3.0 High-Throughput Architecture.
 *              Outputs two 32-bit round constants ({K_{t+1}, K_t}) per cycle
 *              addressed by a 5-bit step index [0..31].
 * Specification: docs/08_v3_throughput_architecture.md
 * ============================================================================
 */

module sha256_k_rom_unrolled (
    input  wire [4:0]  step,          // 5-bit step address [0..31]
    output reg  [31:0] k_t,           // Constant K for Round A (2*step)
    output reg  [31:0] k_t_plus_1,    // Constant K for Round B (2*step + 1)
    output wire [63:0] k_out          // Concatenated {k_t_plus_1, k_t}
);

    assign k_out = {k_t_plus_1, k_t};

    always @(*) begin
        case (step)
            5'd0:  begin k_t = 32'h428a2f98; k_t_plus_1 = 32'h71374491; end // Rounds 0, 1
            5'd1:  begin k_t = 32'hb5c0fbcf; k_t_plus_1 = 32'he9b5dba5; end // Rounds 2, 3
            5'd2:  begin k_t = 32'h3956c25b; k_t_plus_1 = 32'h59f111f1; end // Rounds 4, 5
            5'd3:  begin k_t = 32'h923f82a4; k_t_plus_1 = 32'hab1c5ed5; end // Rounds 6, 7
            5'd4:  begin k_t = 32'hd807aa98; k_t_plus_1 = 32'h12835b01; end // Rounds 8, 9
            5'd5:  begin k_t = 32'h243185be; k_t_plus_1 = 32'h550c7dc3; end // Rounds 10, 11
            5'd6:  begin k_t = 32'h72be5d74; k_t_plus_1 = 32'h80deb1fe; end // Rounds 12, 13
            5'd7:  begin k_t = 32'h9bdc06a7; k_t_plus_1 = 32'hc19bf174; end // Rounds 14, 15
            5'd8:  begin k_t = 32'he49b69c1; k_t_plus_1 = 32'hefbe4786; end // Rounds 16, 17
            5'd9:  begin k_t = 32'h0fc19dc6; k_t_plus_1 = 32'h240ca1cc; end // Rounds 18, 19
            5'd10: begin k_t = 32'h2de92c6f; k_t_plus_1 = 32'h4a7484aa; end // Rounds 20, 21
            5'd11: begin k_t = 32'h5cb0a9dc; k_t_plus_1 = 32'h76f988da; end // Rounds 22, 23
            5'd12: begin k_t = 32'h983e5152; k_t_plus_1 = 32'ha831c66d; end // Rounds 24, 25
            5'd13: begin k_t = 32'hb00327c8; k_t_plus_1 = 32'hbf597fc7; end // Rounds 26, 27
            5'd14: begin k_t = 32'hc6e00bf3; k_t_plus_1 = 32'hd5a79147; end // Rounds 28, 29
            5'd15: begin k_t = 32'h06ca6351; k_t_plus_1 = 32'h14292967; end // Rounds 30, 31
            5'd16: begin k_t = 32'h27b70a85; k_t_plus_1 = 32'h2e1b2138; end // Rounds 32, 33
            5'd17: begin k_t = 32'h4d2c6dfc; k_t_plus_1 = 32'h53380d13; end // Rounds 34, 35
            5'd18: begin k_t = 32'h650a7354; k_t_plus_1 = 32'h766a0abb; end // Rounds 36, 37
            5'd19: begin k_t = 32'h81c2c92e; k_t_plus_1 = 32'h92722c85; end // Rounds 38, 39
            5'd20: begin k_t = 32'ha2bfe8a1; k_t_plus_1 = 32'ha81a664b; end // Rounds 40, 41
            5'd21: begin k_t = 32'hc24b8b70; k_t_plus_1 = 32'hc76c51a3; end // Rounds 42, 43
            5'd22: begin k_t = 32'hd192e819; k_t_plus_1 = 32'hd6990624; end // Rounds 44, 45
            5'd23: begin k_t = 32'hf40e3585; k_t_plus_1 = 32'h106aa070; end // Rounds 46, 47
            5'd24: begin k_t = 32'h19a4c116; k_t_plus_1 = 32'h1e376c08; end // Rounds 48, 49
            5'd25: begin k_t = 32'h2748774c; k_t_plus_1 = 32'h34b0bcb5; end // Rounds 50, 51
            5'd26: begin k_t = 32'h391c0cb3; k_t_plus_1 = 32'h4ed8aa4a; end // Rounds 52, 53
            5'd27: begin k_t = 32'h5b9cca4f; k_t_plus_1 = 32'h682e6ff3; end // Rounds 54, 55
            5'd28: begin k_t = 32'h748f82ee; k_t_plus_1 = 32'h78a5636f; end // Rounds 56, 57
            5'd29: begin k_t = 32'h84c87814; k_t_plus_1 = 32'h8cc70208; end // Rounds 58, 59
            5'd30: begin k_t = 32'h90befffa; k_t_plus_1 = 32'ha4506ceb; end // Rounds 60, 61
            5'd31: begin k_t = 32'hbef9a3f7; k_t_plus_1 = 32'hc67178f2; end // Rounds 62, 63
            default: begin k_t = 32'd0; k_t_plus_1 = 32'd0; end
        endcase
    end

endmodule
