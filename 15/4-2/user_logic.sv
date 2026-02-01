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
        input wire update_dr,
    // 'fast' clock
        input wire conf_clk
);

localparam int RESULT_WIDTH = 128;

localparam int UPSTREAM_BYPASS_BITS = 1; // ARM DAP controller in BYPASS mode
localparam int INBOUND_DATA_WIDTH = $bits(byte);
localparam int CDC_SYNC_STAGES = 3;
localparam int SECRET_KEY_WIDTH = 8 * 12; // 12 ASCII chars max
localparam int HASH_SUFFIX_DIGITS = 7; // should be enough
localparam int MD5_BLOCK_LENGTH = 64; // bytes
localparam int MAX_MSG_LENGTH = MD5_BLOCK_LENGTH-8; // bytes
localparam int DIGEST_WIDTH = 128; // bits

typedef logic [INBOUND_DATA_WIDTH-1:0] inbound_data_t;
typedef logic [RESULT_WIDTH-1:0] result_t;
typedef logic [SECRET_KEY_WIDTH-1:0] secret_key_t;
typedef logic [4-1:0] secret_key_chars_t;
typedef logic [8*HASH_SUFFIX_DIGITS-1:0] suffix_ascii_t;
typedef logic [$clog2(1+HASH_SUFFIX_DIGITS)-1:0] suffix_digits_t;
typedef logic [8*MD5_BLOCK_LENGTH-1:0] md5_block_t;
typedef logic [DIGEST_WIDTH-1:0] digest_t;

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

logic [CDC_SYNC_STAGES-1:0] reset_cclk_shift_reg = '0;
logic [CDC_SYNC_STAGES-1:0] secret_key_valid_cclk_shift_reg = '0;
logic [CDC_SYNC_STAGES-1:0] outbound_valid_tck_shift_reg = '0;
logic reset_cclk;
logic secret_key_valid_cclk;
logic outbound_valid_tck;

always_ff @(posedge conf_clk) begin
    reset_cclk_shift_reg <= CDC_SYNC_STAGES'({reset_cclk_shift_reg, reset});
end
assign reset_cclk = reset_cclk_shift_reg[CDC_SYNC_STAGES-1];

always_ff @(posedge conf_clk) begin
    secret_key_valid_cclk_shift_reg <= CDC_SYNC_STAGES'({secret_key_valid_cclk_shift_reg, secret_key_valid});
end
assign secret_key_valid_cclk = secret_key_valid_cclk_shift_reg[CDC_SYNC_STAGES-1];

logic suffix_ready, suffix_valid;
suffix_ascii_t suffix_number;
suffix_digits_t suffix_digits;

ascii_counter #(
    .DIGITS(HASH_SUFFIX_DIGITS)
) ascii_counter_i (
    .clk(conf_clk),
    .reset(reset_cclk),
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
    .clk(conf_clk),
    .reset(reset_cclk),
    // Decoded Secret Key Data
        .secret_key_valid(secret_key_valid_cclk), // held high
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

logic md5_block_ready, md5_block_valid;
md5_block_t md5_block_data;

message_length_inserter #(
    .MAX_MSG_LENGTH(MAX_MSG_LENGTH), // bytes
    .MD5_BLOCK_LENGTH(MD5_BLOCK_LENGTH) // bytes
) message_length_inserter_i (
    .clk(conf_clk),
    .reset(reset_cclk),
    // Message Without Length
        .msg_ready(msg_ready),
        .msg_valid(msg_valid),
        .msg_length(msg_length), // bytes
        .msg_data(msg_data),
    // MD5 Block With Length
        .md5_block_ready(md5_block_ready),
        .md5_block_valid(md5_block_valid),
        .md5_block_data(md5_block_data)
);

logic outbound_valid, outbound_valid_held = 1'b0;
result_t outbound_data;

md5_engine_units #(
    .BLOCK_WIDTH(8*MD5_BLOCK_LENGTH), // bits
    .RESULT_WIDTH(RESULT_WIDTH)
) md5_engine_units_i (
    .clk(conf_clk),
    .reset(reset_cclk),
    // Block Input
        .md5_block_ready(md5_block_ready),
        .md5_block_valid(md5_block_valid),
        .md5_block_data(md5_block_data),
    // Digest Output
        .result_valid(outbound_valid),
        .result_data(outbound_data)
);

always_ff @(posedge conf_clk) outbound_valid_held <= outbound_valid_held || outbound_valid;

always_ff @(posedge tck) begin
    outbound_valid_tck_shift_reg <= CDC_SYNC_STAGES'({outbound_valid_tck_shift_reg, outbound_valid_held});
end
assign outbound_valid_tck = outbound_valid_tck_shift_reg[CDC_SYNC_STAGES-1];


tap_encoder #(
    .OUTBOUND_DATA_WIDTH(RESULT_WIDTH)
) tap_encoder_i (
    // Deserialized Signals
        .outbound_valid(outbound_valid_tck),
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
