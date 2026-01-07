`timescale 1ns/1ps
`default_nettype none

module line_decoder #(
    parameter int CLICK_BITS
)(
    input wire clk,
    // Inbound Byte Stream
        input wire inbound_valid,
        input wire [8-1:0] inbound_byte,
    // Decoded Line Contents
        output logic end_of_file, // held high
        output logic click_valid,
        output logic click_right_left, // 1: right, 0: left
        output logic [CLICK_BITS-1:0] click_count
);

// from `man ascii`
typedef enum byte {
    NULL_CHAR = 8'h00,
    LF_CHAR = 8'h0A,
    ZERO_CHAR = 8'h30, // `0`
    NINE_CHAR = 8'h39, // `9`
    L_CHAR = 8'h4C, // upper-case `L`
    R_CHAR = 8'h52 // upper-case `R`
} char_t;

logic [8-1:0] prev_inbound_byte = '0;

function automatic logic is_digit(input byte char);
    is_digit = ((char >= ZERO_CHAR) && (char <= NINE_CHAR));
endfunction

initial begin
    end_of_file = 1'b0;
    click_valid = 1'b0;
    click_right_left = 1'b1;
    click_count = '0;
end

always_ff @(posedge clk) begin: decimal_accumulator
    if (inbound_valid) begin
        if (!is_digit(prev_inbound_byte) && is_digit(inbound_byte)) begin: first_digit
            click_count <= CLICK_BITS'(inbound_byte - ZERO_CHAR);
        end else if (is_digit(prev_inbound_byte) && is_digit(inbound_byte)) begin: next_digit
            click_count <= 10 * click_count + CLICK_BITS'(inbound_byte - ZERO_CHAR);
        end
        prev_inbound_byte <= inbound_byte;
    end
end

always_ff @(posedge clk) begin: output_ctrl
    click_valid <= 1'b0;
    if (inbound_valid) begin
        unique case (inbound_byte)
            L_CHAR: begin
                click_right_left <= 1'b0;
            end
            R_CHAR: begin
                click_right_left <= 1'b1;
            end
            LF_CHAR: begin
                click_valid <= (prev_inbound_byte != LF_CHAR);
            end
            NULL_CHAR: begin
                end_of_file <= 1'b1;
            end
            default: begin
            end
        endcase
    end
end

endmodule
`default_nettype wire
