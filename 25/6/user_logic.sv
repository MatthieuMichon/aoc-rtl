`timescale 1ns/1ps
`default_nettype none

module user_logic (
    input wire tck,
    input wire tdi,
    output logic tdo,

    input wire test_logic_reset,
    input wire ir_is_user,
    input wire capture_dr,
    input wire shift_dr,
    input wire update_dr
);

// From puzzle description
localparam int ARG_RANKS = 3;
// From design space exploration
localparam int MAX_ARGUMENT_COUNT = 1000;
localparam int MAX_ARGUMENT_VALUE = 9999;
// Design mapping
localparam int ARG_WIDTH = $clog2(1 + MAX_ARGUMENT_VALUE);
localparam int ARG_ROW_WIDTH = $clog2(ARG_RANKS);
localparam int ARG_COL_WIDTH = $clog2(MAX_ARGUMENT_COUNT);
localparam int BYTE_WIDTH = 8;

logic [BYTE_WIDTH-1:0] inbound_data;
logic inbound_valid;

tap_decoder #(.DATA_WIDTH(BYTE_WIDTH)) tap_decoder_i (
    // TAP signals
        .tck(tck),
        .tdi(tdi),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .shift_dr(shift_dr),
        .update_dr(update_dr),
    // Decoded signals
        .data(inbound_data),
        .valid(inbound_valid)
);

logic arg_valid;
logic [ARG_ROW_WIDTH-1:0] arg_row;
logic [ARG_COL_WIDTH-1:0] arg_col;
logic [ARG_WIDTH-1:0] arg_data;
logic operand_valid;
logic operand_mult_add; // 1: mult, 0: add

input_decoder #(
    .ARG_ROW_WIDTH(ARG_ROW_WIDTH),
    .ARG_COL_WIDTH(ARG_COL_WIDTH),
    .ARG_DATA_WIDTH(ARG_WIDTH)
) input_decoder_i (
    .clk(tck),
    // Inbound Byte Stream
        .byte_valid(inbound_valid),
        .byte_data(inbound_data),
    // Decoded signals
        .arg_valid(arg_valid),
        .arg_row(arg_row),
        .arg_col(arg_col),
        .arg_data(arg_data),
        .operand_valid(operand_valid),
        .operand_mult_add(operand_mult_add)
);

tap_encoder #(.DATA_WIDTH(BYTE_WIDTH)) tap_encoder_i (
    // TAP signals
        .tck(tck),
        .tdo(tdo),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
    // Encoded signals
        .data(arg_row),
        .valid(inbound_valid)
);

endmodule
`default_nettype wire
