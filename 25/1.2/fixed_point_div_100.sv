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

localparam int PRESCALER = 164;
localparam int PRESCALER_WIDTH = $clog2(PRESCALER);
localparam int MULT_WIDTH = ARG_WIDTH + PRESCALER_WIDTH;

logic [MULT_WIDTH-1:0] mult_reg;
logic [ARG_WIDTH-1:0] argument_pipe;
logic valid_sr;

always_ff @(posedge clk) begin
    mult_reg <= argument * PRESCALER_WIDTH'(PRESCALER);
    quotient <= mult_reg >> 14;

    argument_pipe <= argument;
    remainder <= argument_pipe - ((mult_reg >> 14) * 7'd100);

    valid_sr <= input_valid;
    outputs_valid <= valid_sr;
end

endmodule
`default_nettype wire
