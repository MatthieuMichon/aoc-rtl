`timescale 1ns / 1ps
`default_nettype none

module prev_row_stores #(
    parameter int MAX_COLS, // square array
    parameter int COUNT_ROP_WIDTH
) (
    input wire clk,
    // Adjacent Columns Data
        input wire adj_col_last,
        input wire adj_col_valid,
        input wire [COUNT_ROP_WIDTH-1:0] adj_col_rop_count,
        input wire adj_col_rop_mask,
    // Adject count rows
        output logic [$clog2(MAX_COLS)-1:0] row_index,
        output logic next_row,
        output logic [MAX_COLS-1:0][0:COUNT_ROP_WIDTH-1] upper_row_rop_count,
        output logic [MAX_COLS-1:0][0:COUNT_ROP_WIDTH-1] center_row_rop_count,
        output logic [MAX_COLS-1:0] center_row_rop_mask
);

typedef logic [MAX_COLS-1:0][0:COUNT_ROP_WIDTH-1] row_rop_count_t;
typedef logic [MAX_COLS-1:0] row_rop_mask_t;

row_rop_count_t hot_row_rop_count = '{default: '0};
row_rop_mask_t hot_row_mask, upper_row_mask;

logic [$clog2(MAX_COLS)-1:0] current_col = '0;
always_ff @(posedge clk) begin: hot_row_filler
    if (adj_col_valid) begin
        hot_row_rop_count[current_col] <= adj_col_rop_count;
        hot_row_mask[current_col] <= adj_col_rop_mask;
        if (!adj_col_last) begin
            current_col <= current_col + 1;
        end else begin
            current_col <= '0;
        end
    end
end

logic prev_adj_col_last;
always_ff @(posedge clk) prev_adj_col_last <= (adj_col_last && adj_col_valid);

always_ff @(posedge clk) begin: row_shifter
    if (prev_adj_col_last) begin
        row_index <= row_index + 1;
        next_row <= 1'b1;
        upper_row_rop_count <= center_row_rop_count;
        center_row_rop_count <= hot_row_rop_count;
        center_row_rop_mask <= hot_row_mask;
    end else begin
        next_row <= 1'b0;
    end
end

endmodule
`default_nettype wire
