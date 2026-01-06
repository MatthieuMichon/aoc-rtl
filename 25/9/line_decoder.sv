`timescale 1ns/1ps
`default_nettype none

module line_decoder #(
    parameter int GRID_BITS
)(
    input wire clk,
    // Inbound Byte Stream
        input wire inbound_valid,
        input wire [8-1:0] inbound_byte,
    // Decoded Line Contents
        output logic end_of_file, // held high
        output logic tile_valid,
        output logic [GRID_BITS-1:0] tile_row,
        output logic [GRID_BITS-1:0] tile_col
);

// from `man ascii`
typedef enum byte {
    NULL_CHAR = 8'h00,
    LF_CHAR = 8'h0A,
    COMA_CHAR = 8'h2C, // `,`
    ZERO_CHAR = 8'h30, // `0`
    NINE_CHAR = 8'h39 // `9`
} char_t;

typedef logic [GRID_BITS-1:0] position_t;
logic [8-1:0] prev_inbound_byte = '0;
position_t position = '0;

function automatic logic is_digit(input byte char);
    is_digit = ((char >= ZERO_CHAR) && (char <= NINE_CHAR));
endfunction

always_ff @(posedge clk) begin: decimal_accumulator
    if (inbound_valid) begin
        if (!is_digit(prev_inbound_byte) && is_digit(inbound_byte)) begin: first_digit
            position <= GRID_BITS'(inbound_byte - ZERO_CHAR);
        end else if (is_digit(prev_inbound_byte) && is_digit(inbound_byte)) begin: next_digit
            position <= 10 * position + GRID_BITS'(inbound_byte - ZERO_CHAR);
        end
        prev_inbound_byte <= inbound_byte;
    end
end

initial begin
    end_of_file = 1'b0;
    tile_valid = 1'b0;
    tile_row = '0;
    tile_col = '0;
end

always_ff @(posedge clk) begin: output_ctrl
    tile_valid <= 1'b0;
    if (inbound_valid) begin
        unique case (inbound_byte)
            COMA_CHAR: begin
                tile_row <= position;
            end
            LF_CHAR: begin
                tile_valid <= 1'b1;
                tile_col <= position;
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
