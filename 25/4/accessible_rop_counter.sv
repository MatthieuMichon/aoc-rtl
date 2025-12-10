`timescale 1ns / 1ps
`default_nettype none

module accessible_rop_counter #(
    parameter int MAX_COLS,
    parameter int COUNT_ROP_WIDTH,
    parameter int RESULT_WIDTH
) (
    input wire clk,
    // Lower Row Adjacent Columns Data
        input wire adj_col_last,
        input wire adj_col_valid,
        input wire [COUNT_ROP_WIDTH-1:0] adj_col_rop_count,
        input wire adj_col_rop_mask,
    // Adjacent Rows Data
        input wire [$clog2(MAX_COLS)-1:0] row_index,
        input wire next_row,
        input wire [MAX_COLS-1:0][COUNT_ROP_WIDTH-1:0] upper_row_rop_count,
        input wire [MAX_COLS-1:0][COUNT_ROP_WIDTH-1:0] center_row_rop_count,
        input wire [MAX_COLS-1:0] center_row_rop_mask,
    // Result
        output logic [RESULT_WIDTH-1:0] accessible_rop_count,
        output logic accessible_rop_valid
);

localparam int MAX_ADJACENT_ROP_FOR_ACCESS = 3;

typedef logic [$clog2(MAX_COLS)-1:0] col_index_t;
col_index_t col_index = '0, col_count = '0;

always_ff @(posedge clk) begin: count_effective_cols
    if (adj_col_valid) begin
        if (!adj_col_last) begin
            col_index <= col_index + 1;
        end else begin
            col_index <= '0;
        end
    end
end

always_ff @(posedge clk) col_count <= (col_count < (col_index + 1)) ? (col_index + 1) : col_count;

logic [2-1:0] upper_row_count, center_row_count;
assign upper_row_count = upper_row_rop_count[col_index];
assign center_row_count = center_row_rop_count[col_index];

initial accessible_rop_count = '0;

always_ff @(posedge clk) begin
    accessible_rop_valid <= 1'b0;
    if (adj_col_valid && (row_index > 0)) begin: center_cell_with_rop
        accessible_rop_valid <= 1'b1;
        if (row_index == 1) begin: first_row
            if (center_row_count + adj_col_rop_count - 1 <= MAX_ADJACENT_ROP_FOR_ACCESS) begin
                accessible_rop_count <= accessible_rop_count + center_row_rop_mask[col_index];
            end
        end else if (row_index < (col_count - 1)) begin: middle_rows
            if (upper_row_count + center_row_count + adj_col_rop_count - 1 <= MAX_ADJACENT_ROP_FOR_ACCESS) begin
                accessible_rop_count <= accessible_rop_count + center_row_rop_mask[col_index];
            end
        end else begin: last_row // consider rows {N-2:N} and {N-1:N}
            if ((center_row_rop_mask[col_index]) && (upper_row_count + center_row_count + adj_col_rop_count - 1 <= MAX_ADJACENT_ROP_FOR_ACCESS)) begin
                if (adj_col_rop_mask && (center_row_count + adj_col_rop_count - 1 <= MAX_ADJACENT_ROP_FOR_ACCESS)) begin
                    accessible_rop_count <= accessible_rop_count + 2;
                end else begin
                    accessible_rop_count <= accessible_rop_count + 1;
                end
            end else if (adj_col_rop_mask && (center_row_count + adj_col_rop_count - 1 <= MAX_ADJACENT_ROP_FOR_ACCESS)) begin
                accessible_rop_count <= accessible_rop_count + 1;
            end
        end
    end
end

endmodule
`default_nettype wire
