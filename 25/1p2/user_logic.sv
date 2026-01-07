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
localparam int CLICK_BITS = 10;
localparam int DIAL_CLICKS = 100;
localparam int RESULT_WIDTH = 16;

typedef logic [CLICK_BITS-1:0] click_cnt_t;
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

logic end_of_file, click_valid, click_right_left;
click_cnt_t click_count;

line_decoder #(.CLICK_BITS(CLICK_BITS)) line_decoder_i (
    .clk(tck),
    // Inbound Byte Stream
        .inbound_valid(inbound_valid),
        .inbound_byte(inbound_data),
    // Decoded Line Contents
        .end_of_file(end_of_file), // held high
        .click_valid(click_valid),
        .click_right_left(click_right_left),
        .click_count(click_count)
);

logic zero_crossings_valid;
click_cnt_t zero_crossings_count;

dial_tracker #(
    .CLICK_BITS(CLICK_BITS),
    .DIAL_CLICKS(DIAL_CLICKS)
) dial_tracker_i (
    .clk(tck),
    // Decoded Line Contents
        .click_valid(click_valid),
        .click_right_left(click_right_left),
        .click_count(click_count),
    // Computed Values
        .zero_crossings_valid(zero_crossings_valid),
        .zero_crossings_count(zero_crossings_count)
);

logic outbound_valid;
logic [RESULT_WIDTH-1:0] outbound_data = '0;

always_ff @(posedge tck) begin
    if (test_logic_reset) begin
        outbound_valid <= 1'b0;
        outbound_data <= '0;
    end else begin
        outbound_valid <= end_of_file;
        if (zero_crossings_valid) begin
            outbound_data <= outbound_data + RESULT_WIDTH'(zero_crossings_count);
        end
    end
end

tap_encoder #(.DATA_WIDTH(RESULT_WIDTH)) tap_encoder_i (
    // Encoded signals
        .valid(outbound_valid),
        .data(outbound_data),
    // TAP signals
        .tck(tck),
        .tdo(tdo),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr)
);

wire _unused_ok = 1'b0 && &{1'b0,
    run_test_idle, test_logic_reset,
    1'b0};

endmodule
`default_nettype wire
