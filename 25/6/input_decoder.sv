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

typedef logic [ARG_ROW_WIDTH-1:0] arg_row_t;
typedef logic [ARG_COL_WIDTH-1:0] arg_col_t;
typedef logic [ARG_DATA_WIDTH-1:0] arg_data_t;

// row and col values must be updated after data, requiring registers for both
arg_row_t arg_row_int;
arg_col_t arg_col_int;

initial begin
    arg_row_int = '0;
    arg_col_int = '0;
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
        arg_row_int <= arg_row_int + 1'b1;
    end
end

always_ff @(posedge clk) arg_row <= arg_row_int;

localparam arg_row_t OPERAND_ROW = 2'b11;

logic char_is_text, prev_char_was_text;
assign char_is_text =
    ((byte_data >= ZERO_CHAR) && (byte_data <= NINE_CHAR)) ||
    (byte_data == ADD_CHAR) || (byte_data == MULT_CHAR);
always_ff @(posedge clk) begin
    if (byte_valid) begin
        prev_char_was_text <= char_is_text;
    end
end

always_ff @(posedge clk) begin: track_col
    if (byte_valid) begin
        if (byte_data == SPACE_CHAR) begin
            if (prev_char_was_text) begin: first_space_char
                arg_col_int <= arg_col_int + 1'b1;
            end
        end else if (byte_data == LF_CHAR) begin
            arg_col_int <= '0;
        end
    end
end

always_ff @(posedge clk) arg_col <= arg_col_int;

logic char_is_digit, prev_char_was_digit;
assign char_is_digit = (byte_data >= ZERO_CHAR) && (byte_data <= NINE_CHAR);
always_ff @(posedge clk) begin
    if (byte_valid) begin
        prev_char_was_digit <= char_is_digit;
    end
end

always_ff @(posedge clk) begin: accumulate_arg
    arg_valid <= 1'b0;
    if (byte_valid) begin
        if (char_is_digit) begin
            if (!prev_char_was_digit) begin: first_digit
                arg_data <= byte_data & 8'h0F;
            end else begin: subsequent_digit
                arg_data <= 10 * arg_data + (byte_data & 8'h0F);
            end
        end else begin
            if (prev_char_was_digit) begin: arg_complete
                arg_valid <= (arg_row_int < OPERAND_ROW);
            end
        end
    end
end

always_ff @(posedge clk) begin: track_operand
    if (byte_valid && (arg_row == OPERAND_ROW)) begin
        if (byte_data == ADD_CHAR) begin
            operand_valid <= 1'b1;
            operand_mult_add <= 1'b0;
        end else if (byte_data == MULT_CHAR) begin
            operand_valid <= 1'b1;
            operand_mult_add <= 1'b1;
        end
    end else begin
        operand_valid <= 1'b0;
        operand_mult_add <= 1'b0;
    end
end

endmodule
`default_nettype wire
