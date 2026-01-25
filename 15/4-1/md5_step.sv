`timescale 1ns/1ps
`default_nettype none

module md5_step #(
    parameter int WORD_BITS
) (
    input wire clk,
    input wire reset,
    // Per-Step Inputs
        input  logic [WORD_BITS-1:0] x_k,    // Message word
        input  logic [WORD_BITS-1:0] t_i,    // Constant
        input  logic [5-1:0] shift,      // Shift amount
        input  logic [2-1:0] mode,   // 0=F, 1=G, 2=H, 3=I
    // Upstream / Downstream Steps
        input wire i_valid,
        input wire [WORD_BITS-1:0] i_a, i_b, i_c, i_d,
        output logic o_valid,
        output logic [WORD_BITS-1:0] o_a, o_b, o_c, o_d

);

assign o_valid = i_valid;
assign o_a = i_a;
assign o_b = i_b;
assign o_c = i_c;
assign o_d = i_d;

endmodule
`default_nettype wire
