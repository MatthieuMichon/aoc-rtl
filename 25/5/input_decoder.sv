`timescale 1ns/1ps
`default_nettype none

module input_decoder #(
    parameter int INGREDIENT_ID_RANGE_WIDTH
)(
    input wire clk,
    // Inbound Byte Stream
        input wire byte_valid,
        input wire [8-1:0] byte_data,
    // Decoded signals
        output logic id_range_sel,   // 1: ingredient ID, 0: range
        output logic id_range_valid,
        output logic [INGREDIENT_ID_RANGE_WIDTH-1:0] id_range_data
);

localparam int MAX_CHAR_CNT = $ceil(INGREDIENT_ID_RANGE_WIDTH/8);
typedef logic [INGREDIENT_ID_RANGE_WIDTH-1:0] data_t;
logic [MAX_CHAR_CNT-1:0] char_cnt;

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

byte prev_byte_data;
always_ff @(posedge clk) begin
    if (byte_valid) begin
        prev_byte_data <= byte_data;
    end
end

initial id_range_sel = 1'b0;
always_ff @(posedge clk) begin: detect_blank_line
    if (byte_valid) begin
        if (!is_digit(prev_byte_data) && (byte_data == LF_CHAR)) begin: blank_line
            id_range_sel <= 1'b1;
        end
    end
end

always_ff @(posedge clk) begin: data_accumulator
    id_range_valid <= 1'b0;
    if (byte_valid) begin
        if (!is_digit(prev_byte_data) && is_digit(byte_data)) begin: first_digit
            id_range_data <= byte_data - ZERO_CHAR;
        end else if (is_digit(prev_byte_data) && is_digit(byte_data)) begin: next_digit
            id_range_data <= 10*id_range_data + (byte_data - ZERO_CHAR);
        end else if (is_digit(prev_byte_data) && !is_digit(byte_data)) begin: end_of_number
            id_range_valid <= 1'b1;
        end
    end
end

endmodule
`default_nettype wire
