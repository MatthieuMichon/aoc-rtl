`timescale 1ns/1ps
`default_nettype none

module suffix_extractor #(
    parameter int BLOCK_HEADER_WIDTH,
    parameter int RESULT_WIDTH
) (
    input wire clk,
    input wire reset,
    // Block Input
        input wire block_header_valid,
        input wire [BLOCK_HEADER_WIDTH-1:0] block_header_data,
    // Digest Output
        output logic result_valid,
        output logic [RESULT_WIDTH-1:0] result_data
);

localparam int DIGITS = BLOCK_HEADER_WIDTH/8;

typedef enum logic [8-1:0] {
    ASCII_ZERO = 8'h30,
    ASCII_ONE = 8'h31,
    ASCII_NINE = 8'h39
} ascii_digit_t;

typedef logic [BLOCK_HEADER_WIDTH-1:0] header_t;
typedef logic [8-1:0] char_t;
typedef logic [4*DIGITS-1:0] count_t;

header_t header_mask, header_aligned;
char_t char;
logic [$clog2(DIGITS)-1:0] shift_digits;
count_t sum_at_digit[0:DIGITS];
count_t final_sum;

function automatic logic is_digit(input char_t char_);
    is_digit = (char_ >= ASCII_ZERO && char_ <= ASCII_NINE);
endfunction

always_comb begin: tag_digits
    logic has_captured_digit = 1'b0;
    header_mask = '0;
    shift_digits = '0;
    for (int i = 0; i < DIGITS; i = i + 1) begin
        char = block_header_data[i*8+:8];
        header_mask[i*8+:8] = {8{is_digit(char)}};
        if (!has_captured_digit && is_digit(char)) begin
            has_captured_digit = 1'b1;
            shift_digits = $bits(shift_digits)'(i);
        end
    end
end

always_ff @(posedge clk) header_aligned <= (block_header_data & header_mask) >> (8*shift_digits);

genvar i; generate
for (i = 0; i < DIGITS; i = i + 1) begin
    localparam int MULT_FACTOR = 10**i;
    always_ff @(posedge clk) begin: per_digit_mac
        if (i == 0) begin: first_digit
            sum_at_digit[i] <= (4*DIGITS)'(header_aligned[4-1:0]);
        end else begin: higher_digit
            sum_at_digit[i] <= (sum_at_digit[i-1]) + MULT_FACTOR * header_aligned[i*8+:4];
        end
    end
end endgenerate

assign final_sum = sum_at_digit[DIGITS-1];

always_ff @(posedge clk) begin
    if (reset) begin
        result_valid <= 1'b0;
    end else begin
        result_valid <= block_header_valid;
        if (block_header_valid) begin
            result_data <= RESULT_WIDTH'(final_sum);
        end
    end
end

wire _unused_ok = 1'b0 && &{1'b0,
    header_aligned,
    1'b0};

endmodule
`default_nettype wire
