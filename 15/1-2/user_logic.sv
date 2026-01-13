`timescale 1ns/1ps
`default_nettype none

module user_logic (
    // raw JTAG signals
        input wire tck,
        input wire tdi,
        output logic tdo,
    // TAP controller states
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

typedef logic [RESULT_WIDTH-1:0] result_t;

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

logic outbound_valid;
logic [RESULT_WIDTH-1:0] outbound_data;

floor_tracker #(.RESULT_WIDTH(RESULT_WIDTH)) floor_tracker_i (
    .clk(tck),
    .reset(test_logic_reset),
    // Inbound Byte Stream
        .inbound_valid(inbound_valid),
        .inbound_data(inbound_data),
    // Decoded Line Contents
        .outbound_valid(outbound_valid),
        .outbound_data(outbound_data)
);

tap_encoder #(.DATA_WIDTH(RESULT_WIDTH)) tap_encoder_i (
    .tck(tck),
    // Encoded signals
        .valid(outbound_valid),
        .data(outbound_data),
    // TAP signals
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
        .tdo(tdo)
);

wire _unused_ok = 1'b0 && &{1'b0,
    run_test_idle,
    1'b0};

endmodule
`default_nettype wire
