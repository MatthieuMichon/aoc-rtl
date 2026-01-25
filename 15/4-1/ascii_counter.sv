`timescale 1ns/1ps
`default_nettype none

module ascii_counter #(
    parameter int DIGITS
)(
    input wire clk,
    input wire reset,
    input wire count_en,
    output logic ascii_valid,
    output logic [8*DIGITS-1:0] ascii_digits,
    output logic [$clog2(1+DIGITS)-1:0] enabled_digits
);

typedef enum logic [8-1:0] {
    ASCII_ZERO = 8'h30,
    ASCII_ONE = 8'h31,
    ASCII_NINE = 8'h39
} char_t;

logic [DIGITS-1:0] carry;
assign carry[0] = count_en;
assign ascii_valid = 1'b1;

genvar i;
generate
    for (i = 0; i < DIGITS; i++) begin: per_digit

        char_t current_digit;
        assign current_digit = char_t'(ascii_digits[8*i+:8]);

        if (i < DIGITS - 1) begin: all_but_last
            assign carry[i+1] = (current_digit == ASCII_NINE) && carry[i];
        end

        always_ff @(posedge clk) begin
            if (reset) begin
                ascii_digits[8*i+:8] <= (i != 0) ? ASCII_ZERO : ASCII_ONE;
            end else if (carry[i]) begin
                if (current_digit == ASCII_NINE)
                    ascii_digits[8*i+:8] <= ASCII_ZERO;
                else
                    ascii_digits[8*i+:8] <= ascii_digits[8*i+:8] + 1'b1;
            end
        end
    end
endgenerate

always_comb begin: check_enabled_digits
    enabled_digits = 1;
    for (int j = 0; j < DIGITS; j++) begin
        if (ascii_digits[8*j+:8] != ASCII_ZERO) begin
            enabled_digits = $bits(enabled_digits)'(j + 1);
        end
    end
end

endmodule
`default_nettype wire
