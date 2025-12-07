`timescale 1ns/1ps
`default_nettype none

module user_logic_stub (
    input wire tck,
    input wire tdi,
    output logic tdo,

    input wire test_logic_reset,
    input wire ir_is_user,
    input wire capture_dr,
    input wire shift_dr,
    input wire update_dr
);

localparam int INBOUND_DATA_WIDTH = 8;
typedef logic [INBOUND_DATA_WIDTH-1:0] data_t;
data_t inbound_data;
logic inbound_valid;

tap_decoder #(.DATA_WIDTH(INBOUND_DATA_WIDTH)) tap_decoder_i (
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

tap_encoder #(.DATA_WIDTH(INBOUND_DATA_WIDTH)) tap_encoder_i (
    // TAP signals
        .tck(tck),
        .tdo(tdo),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
    // Encoded signals
        .data(inbound_data),
        .valid(inbound_valid)
);

endmodule
`default_nettype wire
