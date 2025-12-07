`timescale 1ns/1ps
`default_nettype none

module input_decoder #(
    parameter int ARG_ROW_WIDTH,
    parameter int ARG_COL_WIDTH,
    parameter int ARG_DATA_WIDTH
)(
    input wire clk,
    // Inbound Byte Stream
        input wire byte_valid,
        input wire [8-1:0]byte_data,
    // Decoded signals
        output logic arg_valid,
        output logic [ARG_ROW_WIDTH-1:0] arg_row,
        output logic [ARG_COL_WIDTH-1:0] arg_col,
        output logic [ARG_DATA_WIDTH-1:0] arg_data,
        output logic operand_valid,
        output logic operand_mult_add
);

initial begin
    arg_row = '0;
    arg_col = '0;
    arg_data = '0;
end

// from `man ascii`
typedef enum byte {
    ZERO_CHAR = 8'h30,
    NINE_CHAR = 8'h39,
    SPACE_CHAR = 8'h20,
    LF_CHAR = 8'h0A,
    ADD_CHAR = 8'h2B,
    MULT_CHAR = 8'h2A
} char_t;

always_ff @(posedge clk) begin: track_row
    if (byte_valid && (byte_data == LF_CHAR)) begin
        arg_row <= arg_row + 1'b1;
    end
end

logic prev_char_was_space;

always_ff @(posedge clk) begin: track_col
    arg_valid <= 1'b0;
    if (byte_valid) begin
        if (byte_data == SPACE_CHAR) begin
            if (!prev_char_was_space) begin: first_space_char
                arg_valid <= 1'b1;
                arg_col <= arg_col + 1'b1;
            end else begin: repeated_space_char
            end
        end else if (byte_data == LF_CHAR) begin
            arg_valid <= 1'b1;
            arg_col <= '0;
        end
        prev_char_was_space <= ((byte_data == SPACE_CHAR) || (byte_data == LF_CHAR));
    end
end

endmodule
`default_nettype wire
