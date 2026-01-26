`timescale 1ns/1ps
`default_nettype none

module md5_step #(
    parameter int ROUND, // from 0 to 63
    parameter int WORD_BITS = 32,
    parameter logic [WORD_BITS-1:0] T_CONST,
    parameter int LROT_BITS
) (
    input wire clk,
    input wire reset,
    // Per-Step Inputs
        input wire [WORD_BITS-1:0] message,
    // Upstream / Downstream Steps
        input wire i_valid,
        input wire [WORD_BITS-1:0] i_a, i_b, i_c, i_d,
        output logic o_valid,
        output logic [WORD_BITS-1:0] o_a, o_b, o_c, o_d
);

localparam logic [2-1:0] MODE = 2'(ROUND / 16);

typedef logic [WORD_BITS-1:0] word_t;

word_t f, a_sum, b_new;

always_comb begin: update_b_word
    unique case (MODE)
        2'b00: f = (i_b & i_c) | (~i_b & i_d);
        2'b01: f = (i_b & i_d) | (i_c & ~i_d);
        2'b10: f = i_b ^ i_c ^ i_d;
        2'b11: f = i_c ^ (i_b | ~i_d);
        default: f = '0;
    endcase
    a_sum = (i_a + f + message + T_CONST);
    b_new = i_b + {a_sum[WORD_BITS-LROT_BITS-1:0], a_sum[WORD_BITS-1:WORD_BITS-LROT_BITS]};
end

always_ff @(posedge clk) begin: output_register
    if (reset) begin
        o_valid <= 1'b0;
    end else begin
        o_valid <= i_valid;
        o_a <= i_d;
        o_b <= b_new;
        o_c <= i_b;
        o_d <= i_c;
    end
end

endmodule
`default_nettype wire
