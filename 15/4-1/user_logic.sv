`timescale 1ns/1ps
`default_nettype none

module user_logic (
    // TAP Controller Raw JTAG signals
        input wire tck,
        input wire tms,
        input wire tdi,
        output logic tdo,
    // TAP Controller States
        input wire test_logic_reset,
        input wire ir_is_user,
        input wire run_test_idle,
        input wire capture_dr,
        input wire shift_dr,
        input wire update_dr
);

localparam int RESULT_WIDTH = 16;

localparam int UPSTREAM_BYPASS_BITS = 1; // ARM DAP controller in BYPASS mode
localparam int INBOUND_DATA_WIDTH = $bits(byte);
localparam int SECRET_KEY_WIDTH = 8 * 12; // 12 ASCII chars max
localparam int HASH_SUFFIX_DIGITS = 7; // should be enough
localparam int MAX_MSG_LENGTH = 56; // bytes

typedef logic [INBOUND_DATA_WIDTH-1:0] inbound_data_t;
typedef logic [RESULT_WIDTH-1:0] result_t;
typedef logic [SECRET_KEY_WIDTH-1:0] secret_key_t;
typedef logic [4-1:0] secret_key_chars_t;
typedef logic [8*HASH_SUFFIX_DIGITS-1:0] suffix_ascii_t;
typedef logic [$clog2(1+HASH_SUFFIX_DIGITS)-1:0] suffix_digits_t;

logic inbound_alignment_error;
logic inbound_valid;
inbound_data_t inbound_data;

tap_decoder #(
    .INBOUND_DATA_WIDTH(INBOUND_DATA_WIDTH),
    .UPSTREAM_BYPASS_BITS(UPSTREAM_BYPASS_BITS)
) tap_decoder_i (
    // JTAG TAP Controller Signals
        .tck(tck),
        .tms(tms),
        .tdi(tdi),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .shift_dr(shift_dr),
        .update_dr(update_dr),
    // Deserialized Data
        .inbound_alignment_error(inbound_alignment_error),
        .inbound_valid(inbound_valid),
        .inbound_data(inbound_data)
);

logic reset;
logic secret_key_valid;
secret_key_chars_t secret_key_chars;
secret_key_t secret_key_value;

assign reset = test_logic_reset || !ir_is_user;

line_decoder #(
    .INBOUND_DATA_WIDTH(INBOUND_DATA_WIDTH),
    .SECRET_KEY_WIDTH(SECRET_KEY_WIDTH)
) line_decoder_i (
    .clk(tck),
    .reset(reset),
    // Deserialized Data
        .inbound_valid(inbound_valid),
        .inbound_data(inbound_data),
    // Decoded Data
        .secret_key_valid(secret_key_valid), // held high
        .secret_key_chars(secret_key_chars),
        .secret_key_value(secret_key_value)
);

logic suffix_ready, suffix_valid;
suffix_ascii_t suffix_number;
suffix_digits_t suffix_digits;

ascii_counter #(
    .DIGITS(HASH_SUFFIX_DIGITS)
) ascii_counter_i (
    .clk(tck),
    .reset(reset),
    .count_en(suffix_ready),
    .ascii_valid(suffix_valid),
    .ascii_digits(suffix_number),
    .enabled_digits(suffix_digits)
);

logic msg_ready, msg_valid;
logic [6-1:0] msg_length; // bytes
logic [8*MAX_MSG_LENGTH-1:0] msg_data;

message_concat #(
    .MAX_KEY_LENGTH(SECRET_KEY_WIDTH/8), // bytes
    .MAX_SUFFIX_LENGTH(HASH_SUFFIX_DIGITS), // bytes
    .MAX_MSG_LENGTH(MAX_MSG_LENGTH) // bytes
) message_concat_i (
    .clk(tck),
    .reset(reset),
    // Decoded Secret Key Data
        .secret_key_valid(secret_key_valid), // held high
        .secret_key_chars(secret_key_chars),
        .secret_key_value(secret_key_value),
    // ASCII Counter Suffix
        .suffix_ready(suffix_ready),
        .suffix_valid(suffix_valid),
        .suffix_digits(suffix_digits),
        .suffix_number(suffix_number),
    // Concatenated Message Output
        .msg_ready(msg_ready),
        .msg_valid(msg_valid),
        .msg_length(msg_length), // bytes
        .msg_data(msg_data)
);

assign msg_ready = 1'b1;

logic outbound_valid;
result_t outbound_data;

always_ff @(posedge tck) begin: capture_result
    if (reset) begin
        outbound_valid <= 1'b0;
        outbound_data <= '0;
    end else begin
        outbound_valid <= msg_valid;
        if (!outbound_valid)
            outbound_data <= RESULT_WIDTH'($countones(msg_length)) + RESULT_WIDTH'($countones(msg_data));
    end
end

tap_encoder #(
    .OUTBOUND_DATA_WIDTH(RESULT_WIDTH)
) tap_encoder_i (
    // Deserialized Signals
        .outbound_valid(outbound_valid),
        .outbound_data(outbound_data),
    // JTAG TAP Controller Signals
        .tck(tck),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
        .tdo(tdo)
);

wire _unused_ok = 1'b0 && &{1'b0,
    inbound_alignment_error,
    secret_key_value,
    run_test_idle,
    suffix_digits,
    1'b0};

endmodule
`default_nettype wire
