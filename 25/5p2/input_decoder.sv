`timescale 1ns/1ps
`default_nettype none

module input_decoder #(
    parameter int RANGE_WIDTH
)(
    input wire clk,
    // Inbound Byte Stream
        input wire inbound_valid,
        input wire [8-1:0] inbound_byte,
    // Decoded signals
        output logic end_of_file, // held high
        output logic range_valid,
        output logic [RANGE_WIDTH-1:0] range_data
);

typedef logic [RANGE_WIDTH-1:0] data_t;

data_t shift_reg = '0;

// from `man ascii`
typedef enum byte {
    ZERO_CHAR = 8'h30,
    NINE_CHAR = 8'h39,
    LF_CHAR = 8'h0A,
    DASH_CHAR = 8'h2D
} char_t;

function automatic logic is_digit(input byte char);
    is_digit = ((char >= ZERO_CHAR) && (char <= NINE_CHAR));
endfunction

byte prev_inbound_byte;
always_ff @(posedge clk) begin
    if (inbound_valid) begin
        prev_inbound_byte <= inbound_byte;
    end
end

initial begin
    end_of_file = 1'b0;
    range_valid = 1'b0;
    range_data = '0;
end

always_ff @(posedge clk) begin: detect_blank_line
    if (inbound_valid) begin
        if ((prev_inbound_byte == LF_CHAR) && (inbound_byte == LF_CHAR)) begin: blank_line
            end_of_file <= 1'b1;
        end
    end
end

always_ff @(posedge clk) begin: data_accumulator
    range_valid <= 1'b0;
    if (inbound_valid && !end_of_file) begin
        if (!is_digit(prev_inbound_byte) && is_digit(inbound_byte)) begin: first_digit
            shift_reg <= RANGE_WIDTH'(inbound_byte - ZERO_CHAR);
        end else if (is_digit(prev_inbound_byte) && is_digit(inbound_byte)) begin: next_digit
            shift_reg <= 10*shift_reg + RANGE_WIDTH'(inbound_byte - ZERO_CHAR);
        end else if (is_digit(prev_inbound_byte) && !is_digit(inbound_byte)) begin: end_of_number
            range_valid <= 1'b1;
            range_data <= shift_reg;
        end
    end
end

endmodule
`default_nettype wire
