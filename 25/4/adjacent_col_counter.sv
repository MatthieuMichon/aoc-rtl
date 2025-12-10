`timescale 1ns / 1ps
`default_nettype none

module adjacent_col_counter #(
    parameter int COUNT_ROP_WIDTH
) (
    input wire clk,
    // Cell data
        input wire cell_last,
        input wire cell_valid,
        input wire cell_rop,
    // Adjacent Columns Data
        output logic adj_col_last,
        output logic adj_col_valid,
        output logic [COUNT_ROP_WIDTH-1:0] adj_col_rop_count,
        output logic adj_col_rop_mask
);

typedef logic [1:0] delay_t;
logic [1:0] cell_rop_sr = '0;
logic next_cell_is_first = 1'b1;
logic prev_cell_is_last = 1'b0;
logic prev_cell_is_rop = 1'b0;

always_ff @(posedge clk) begin: shift_inputs
    if (cell_valid) begin
        prev_cell_is_last <= cell_last;
        prev_cell_is_rop <= cell_rop;
        cell_rop_sr <= {cell_rop_sr[0], cell_rop};
        next_cell_is_first <= 1'b0;
    end else if (prev_cell_is_last) begin: after_last_cell
        prev_cell_is_last <= 1'b0; // single cycle pulse
        cell_rop_sr <= '0;
        next_cell_is_first <= 1'b1;
    end
end

always_ff @(posedge clk) begin: count
    adj_col_valid <= 1'b0;
    if (cell_valid) begin
        adj_col_last <= 1'b0;
        adj_col_valid <= !next_cell_is_first;  // disregard first cell
        adj_col_rop_count <= $countones({cell_rop_sr, cell_rop});
        adj_col_rop_mask <= prev_cell_is_rop;
    end else if (prev_cell_is_last) begin: handle_last_cell
        adj_col_last <= 1'b1;
        adj_col_valid <= 1'b1;
        adj_col_rop_count <= $countones(cell_rop_sr); // cell_rop out of array
        adj_col_rop_mask <= prev_cell_is_rop;
    end
end

endmodule
`default_nettype wire
