`timescale 1ns/1ps
`default_nettype none

module message_concat #(
    parameter int MAX_KEY_LENGTH, // bytes
    parameter int MAX_SUFFIX_LENGTH, // bytes
    parameter int MAX_MSG_LENGTH // bytes
) (
    input wire clk,
    input wire reset,
    // Decoded Secret Key Data
        input wire secret_key_valid, // held high
        input wire [4-1:0] secret_key_chars,
        input wire [8*MAX_KEY_LENGTH-1:0] secret_key_value, // left-aligned, right-padded
    // ASCII Counter Suffix
        output logic suffix_ready,
        input wire suffix_valid,
        input wire [$clog2(1+MAX_SUFFIX_LENGTH)-1:0] suffix_digits,
        input wire [8*MAX_SUFFIX_LENGTH-1:0] suffix_number,
    // Concatenated Message Output
        input wire msg_ready,
        output logic msg_valid,
        output logic [$clog2(MAX_MSG_LENGTH)-1:0] msg_length, // bytes, excludes delimiter
        output logic [8*MAX_MSG_LENGTH-1:0] msg_data
);

localparam logic [8-1:0] PAYLOAD_DELIMITER = 8'h80;

typedef logic [8*MAX_SUFFIX_LENGTH-1:0] suffix_number_t;
typedef logic [8*MAX_MSG_LENGTH-1:0] msg_data_t;
typedef logic [$clog2(MAX_MSG_LENGTH)-1:0] msg_data_len_t;

msg_data_t masked_secret_key_value;
suffix_number_t masked_suffix_number;
msg_data_t concat_suffix, shifted_suffix;
msg_data_len_t msg_shift_bytes;

always_comb begin: mask_secret_key_value
    masked_secret_key_value = '0;
    masked_suffix_number = '0;
    shifted_suffix = '0;
    for (int i = 0; i < MAX_KEY_LENGTH; i++) begin: per_secret_key_char
        if (i < secret_key_chars) begin: enabled_secret_key_char
            masked_secret_key_value[8*(MAX_MSG_LENGTH-1-i)+:8] =
                secret_key_value[8*(MAX_KEY_LENGTH-1-i)+:8];
        end
    end
    for (int j = 0; j < MAX_SUFFIX_LENGTH; j++) begin
        if (j < suffix_digits)
            masked_suffix_number[8*j+:8] = suffix_number[8*j+:8];
    end
    concat_suffix = (8*MAX_MSG_LENGTH)'({masked_suffix_number, PAYLOAD_DELIMITER});
    msg_shift_bytes = msg_data_len_t'(MAX_MSG_LENGTH) - msg_data_len_t'(suffix_digits) - msg_data_len_t'(secret_key_chars) - 1;
    shifted_suffix = concat_suffix << (8*msg_shift_bytes);
end

assign suffix_ready = secret_key_valid && (msg_ready || !msg_valid);

always_ff @(posedge clk) begin
    if (reset) begin
        msg_valid  <= 1'b0;
        msg_length <= '0;
        msg_data <= '0;
    end else begin
        if (suffix_ready) begin
            msg_valid <= suffix_valid;
            if (suffix_valid) begin
                msg_length <= $bits(msg_length)'(secret_key_chars) + $bits(msg_length)'(suffix_digits);
                msg_data <= masked_secret_key_value | shifted_suffix;
            end
        end
    end
end

endmodule
`default_nettype wire
