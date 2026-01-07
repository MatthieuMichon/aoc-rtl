`timescale 1ns/1ps
`default_nettype none

module fixed_point_div_100 #(
    parameter int ARG_WIDTH
)(
    input wire clk,
    // Input Argument
        input wire input_valid,
        input wire [ARG_WIDTH-1:0] argument,
    // Output Quotient and Remainder
        output logic outputs_valid,
        output logic [ARG_WIDTH-1:0] quotient,
        output logic [ARG_WIDTH-1:0] remainder
);

// IMPORTANT: computation is correct for argument values up to 1820 (included)

localparam int MUILTIPLIER = 1311;
localparam int RIGHT_SHIFT = 17;
localparam int MULT_WIDTH = ARG_WIDTH + RIGHT_SHIFT;

logic [MULT_WIDTH-1:0] mult_reg;
logic [ARG_WIDTH-1:0] argument_reg;
logic valid_sr;

always_ff @(posedge clk) begin
    mult_reg <= MULT_WIDTH'(argument) * MULT_WIDTH'(MUILTIPLIER);

    quotient <= ARG_WIDTH'(mult_reg >> RIGHT_SHIFT);
    argument_reg <= argument;
    remainder <= ARG_WIDTH'(argument_reg - ((mult_reg >> RIGHT_SHIFT) * 7'd100));
end

initial begin
    outputs_valid = 1'b0;
end

always_ff @(posedge clk) begin: shift_reg
    valid_sr <= input_valid;
    outputs_valid <= valid_sr;
end

endmodule
`default_nettype wire
