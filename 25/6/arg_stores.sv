`timescale 1ns/1ps
`default_nettype none

module arg_stores #(
    parameter int ARG_ROW_WIDTH,
    parameter int ARG_COL_WIDTH,
    parameter int ARG_DATA_WIDTH
)(
    input wire clk,
    // Decoded signals
        input wire wr_arg_valid,
        input wire [ARG_ROW_WIDTH-1:0] wr_arg_row,
        input wire [ARG_COL_WIDTH-1:0] wr_arg_col,
        input wire [ARG_DATA_WIDTH-1:0] wr_arg_data,
    // Argument readback
        input wire [ARG_COL_WIDTH-1:0] rd_arg_col,
        output logic [ARG_DATA_WIDTH-1:0] rd_arg_data_row0,
        output logic [ARG_DATA_WIDTH-1:0] rd_arg_data_row1,
        output logic [ARG_DATA_WIDTH-1:0] rd_arg_data_row2
);

typedef logic [ARG_ROW_WIDTH-1:0] arg_row_t;
typedef logic [ARG_COL_WIDTH-1:0] arg_col_t;
typedef logic [ARG_DATA_WIDTH-1:0] arg_data_t;

arg_data_t mem_arg_data [0:2**ARG_ROW_WIDTH-1][0:2**ARG_COL_WIDTH-1];

always_ff @(posedge clk) begin: mem_write_logic
    if (wr_arg_valid) begin
        mem_arg_data[wr_arg_row][wr_arg_col] <= wr_arg_data;
    end
end

always_comb begin
    rd_arg_data_row0 = mem_arg_data[0][rd_arg_col];
    rd_arg_data_row1 = mem_arg_data[1][rd_arg_col];
    rd_arg_data_row2 = mem_arg_data[2][rd_arg_col];
end

endmodule
`default_nettype wire
