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
        output logic [ARG_DATA_WIDTH-1:0] rd_arg_data_row2,
        output logic [ARG_DATA_WIDTH-1:0] rd_arg_data_row3,
        output logic [ARG_DATA_WIDTH-1:0] rd_arg_data_row4,
        output logic [ARG_DATA_WIDTH-1:0] rd_arg_data_row5,
        output logic [ARG_DATA_WIDTH-1:0] rd_arg_data_row6,
        output logic [ARG_DATA_WIDTH-1:0] rd_arg_data_row7
);

typedef logic [ARG_ROW_WIDTH-1:0] arg_row_t;
typedef logic [ARG_COL_WIDTH-1:0] arg_col_t;
typedef logic [ARG_DATA_WIDTH-1:0] arg_data_t;

arg_data_t rd_mem[0:2**ARG_ROW_WIDTH-1];
genvar i;
generate
    for (i = 0; i < 2**ARG_ROW_WIDTH; i++) begin
        arg_data_t mem_arg_data[0:2**ARG_COL_WIDTH-1];

        always_ff @(posedge clk) begin: mem_write_logic
            if (wr_arg_valid && (wr_arg_row == i)) begin
                mem_arg_data[wr_arg_col] <= wr_arg_data;
            end
        end

        always_ff @(posedge clk) begin: mem_read_logic
            rd_mem[i] <= mem_arg_data[rd_arg_col];
        end

    end
endgenerate

always_comb begin
    rd_arg_data_row0 = rd_mem[0];
    rd_arg_data_row1 = rd_mem[1];
    rd_arg_data_row2 = rd_mem[2];
    rd_arg_data_row3 = rd_mem[3];
    rd_arg_data_row4 = rd_mem[4];
    rd_arg_data_row5 = rd_mem[5];
    rd_arg_data_row6 = rd_mem[6];
    rd_arg_data_row7 = rd_mem[7];
end

endmodule
`default_nettype wire
