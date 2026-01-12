`timescale 1ns/1ps
`default_nettype none

module line_decoder #(
    parameter int ID_WIDTH
)(
    input wire clk,
    // Inbound Byte Stream
        input wire inbound_valid,
        input wire [8-1:0] inbound_byte,
    // Decoded signals
        output logic end_of_file, // "virtual" EOF, no more contents once asserted
        output logic range_valid,
        output logic [ID_WIDTH-1:0] lower_id,
        output logic [ID_WIDTH-1:0] upper_id
);

// from `man ascii`
typedef enum byte {
    LF_CHAR = 8'h0A,
    DASH_CHAR = 8'h2D,
    ZERO_CHAR = 8'h30,
    NINE_CHAR = 8'h39
} char_t;

typedef logic [$bits(inbound_byte)-1:0] byte_t;
typedef logic [ID_WIDTH-1:0] id_t;

byte_t prev_inbound_byte = '0;
logic lower_id_captured = 1'b0;
id_t lower_id_sr = '0, upper_id_sr = '0;

function automatic logic is_digit(input byte char);
    is_digit = ((char >= ZERO_CHAR) && (char <= NINE_CHAR));
endfunction

initial begin
    end_of_file = 1'b0;
    range_valid = 1'b0;
    lower_id = '0;
    upper_id = '0;
end

always_ff @(posedge clk) begin: detect_eof
    if (inbound_valid) begin
        if ((prev_inbound_byte == LF_CHAR) && (inbound_byte == LF_CHAR)) begin: blank_line
            end_of_file <= 1'b1;
        end
        prev_inbound_byte <= inbound_byte;
    end
end

always_ff @(posedge clk) begin: data_accumulator
    range_valid <= 1'b0;
    if (!end_of_file && inbound_valid) begin
        if (!lower_id_captured) begin: deserialize_lower_id
            if (!is_digit(prev_inbound_byte) && is_digit(inbound_byte)) begin: first_digit
                lower_id_sr <= ID_WIDTH'(inbound_byte - ZERO_CHAR);
            end else if (is_digit(prev_inbound_byte) && is_digit(inbound_byte)) begin: next_digit
                lower_id_sr <= 10*lower_id_sr + ID_WIDTH'(inbound_byte - ZERO_CHAR);
            end else if (is_digit(prev_inbound_byte) && !is_digit(inbound_byte)) begin: end_of_number
                lower_id_captured <= 1'b1;
            end
        end else begin: deserialize_upper_id
            if (!is_digit(prev_inbound_byte) && is_digit(inbound_byte)) begin: first_digit
                upper_id_sr <= ID_WIDTH'(inbound_byte - ZERO_CHAR);
            end else if (is_digit(prev_inbound_byte) && is_digit(inbound_byte)) begin: next_digit
                upper_id_sr <= 10*upper_id_sr + ID_WIDTH'(inbound_byte - ZERO_CHAR);
            end else if (is_digit(prev_inbound_byte) && !is_digit(inbound_byte)) begin: end_of_number
                lower_id_captured <= 1'b0;
                range_valid <= 1'b1;
                lower_id <= lower_id_sr;
                upper_id <= upper_id_sr;
            end
        end
    end
end

endmodule
`default_nettype wire
