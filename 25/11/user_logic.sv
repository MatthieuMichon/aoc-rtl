`timescale 1ns/1ps
`default_nettype none

module user_logic (
    input wire tck,
    input wire tdi,
    output logic tdo,
    input wire test_logic_reset,
    input wire run_test_idle,
    input wire ir_is_user,
    input wire capture_dr,
    input wire shift_dr,
    input wire update_dr
);

localparam int BYTE_WIDTH = $bits(byte);
// From design space exploration
localparam int RESULT_WIDTH = 16;
parameter int DEVICE_CHARS = 3;
parameter int DEVICE_BIN_BITS = 5;
parameter int DEVICE_WIDTH = DEVICE_CHARS*DEVICE_BIN_BITS;

logic inbound_valid;
logic [BYTE_WIDTH-1:0] inbound_data;

tap_decoder #(.DATA_WIDTH(BYTE_WIDTH)) tap_decoder_i (
    // TAP signals
        .tck(tck),
        .tdi(tdi),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .shift_dr(shift_dr),
        .update_dr(update_dr),
    // Decoded signals
        .valid(inbound_valid),
        .data(inbound_data)
);

logic end_of_file;
logic connection_valid;
logic connection_last;
logic [DEVICE_WIDTH-1:0] device;
logic [DEVICE_WIDTH-1:0] next_device;

input_decoder input_decoder_i (
    .clk(tck),
    // Inbound Byte Stream
        .byte_valid(inbound_valid),
        .byte_data(inbound_data),
    // Decoded signals
        .end_of_file(end_of_file),
        .connection_valid(connection_valid),
        .connection_last(connection_last), // for a given device
        .device(device),
        .next_device(next_device)
);

forward_pass_processor forward_pass_processor_i (
    .clk(tck),
    // Connection entries
        .end_of_file(end_of_file),
        .connection_valid(connection_valid),
        .connection_last(connection_last), // for a given device
        .device(device),
        .next_device(next_device)
);

logic outbound_valid;
logic [RESULT_WIDTH-1:0] outbound_data;

tap_encoder #(.DATA_WIDTH(RESULT_WIDTH)) tap_encoder_i (
    // TAP signals
        .tck(tck),
        .tdo(tdo),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
    // Encoded signals
        .valid(outbound_valid),
        .data(outbound_data)
);

endmodule
`default_nettype wire
