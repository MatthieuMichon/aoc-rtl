`timescale 1ns/1ps
`default_nettype none

module line_decoder #(
    parameter int INBOUND_DATA_WIDTH,
    parameter int INSTRUCTION_WIDTH
)(
    input wire clk,
    input wire reset,
    // Deserialized Data
        input wire inbound_alignment_error,
        input wire inbound_valid,
        input wire [INBOUND_DATA_WIDTH-1:0] inbound_data,
    // Normalized Data
        output logic end_of_file,
        output logic normalized_instr_valid,
        output logic [INSTRUCTION_WIDTH-1:0] normalized_instr_data
);

localparam int OPERATION_WIDTH = 2;
localparam int POSITION_WIDTH = 10;

typedef logic [INBOUND_DATA_WIDTH-1:0] inbound_data_t;
typedef logic [OPERATION_WIDTH-1:0] operation_t;
typedef logic [POSITION_WIDTH-1:0] position_t;
// from `man ascii`
typedef enum inbound_data_t {
    NULL_CHAR = 8'h00,
    LF_CHAR = 8'h0A,
    SPACE_CHAR = 8'h20,
    COMA_CHAR = 8'h2C, // ','
    ZERO_CHAR = 8'h30, // '0'
    NINE_CHAR = 8'h39, // '9'
    F_CHAR = 8'h66, // lower-case 'f'
    O_CHAR = 8'h6F, // lower-case 'o'
    N_CHAR = 8'h6E, // lower-case 'n'
    T_CHAR = 8'h74 // lower-case 't'
} char_t;

inbound_data_t prev_char;
logic last, delayed_valid;
operation_t operation;
position_t start_row, start_col, end_row, end_col;

assign normalized_instr_data = {last, delayed_valid, operation, start_row, start_col, end_row, end_col};

endmodule
