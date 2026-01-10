`timescale 1ns/1ps
`default_nettype none

module user_logic (
    // raw JTAG signals
        input wire tck,
        input wire tdi,
        output logic tdo,
    // TAP controller states
        input wire test_logic_reset,
        input wire run_test_idle,
        input wire ir_is_user,
        input wire capture_dr,
        input wire shift_dr,
        input wire update_dr
);

localparam int BYTE_WIDTH = $bits(byte);
// From design space exploration
localparam int MAX_COLS = 160;
localparam int RESULT_WIDTH = 16;

localparam int MAX_ROW_COL_WIDTH = $clog2(MAX_COLS);

logic inbound_valid;
logic [BYTE_WIDTH-1:0] inbound_data;

tap_decoder #(.DATA_WIDTH(BYTE_WIDTH)) tap_decoder_i (
    // TAP signals
        .tck(tck),
        .tdi(tdi),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .shift_dr(shift_dr),
        .update_dr(update_dr),
    // Decoded signals
        .valid(inbound_valid),
        .data(inbound_data)
);

logic cell_last;
logic cell_valid;
logic cell_rop;

input_decoder input_decoder_i (
    .clk(tck),
    // Inbound Byte Stream
        .byte_valid(inbound_valid),
        .byte_data(inbound_data),
    // Decoded signals
        .cell_last(cell_last),
        .cell_valid(cell_valid),
        .cell_rop(cell_rop)
);

localparam int MAX_ADJACENT_ROP_COUNT = 3;
localparam int COUNT_ROP_WIDTH = $clog2(MAX_ADJACENT_ROP_COUNT + 1);

logic adj_col_last;
logic adj_col_valid;
logic [COUNT_ROP_WIDTH-1:0] adj_col_rop_count;
logic adj_col_rop_mask;

adjacent_col_counter #(.COUNT_ROP_WIDTH(COUNT_ROP_WIDTH)) adjacent_col_counter_i (
    .clk(tck),
    // Binary row data
        .cell_last(cell_last),
        .cell_valid(cell_valid),
        .cell_rop(cell_rop),
    // Adjacent Columns Data
        .adj_col_last(adj_col_last),
        .adj_col_valid(adj_col_valid),
        .adj_col_rop_count(adj_col_rop_count),
        .adj_col_rop_mask(adj_col_rop_mask)
);

logic [$clog2(MAX_COLS)-1:0] row_index;
logic next_row;
logic [MAX_COLS-1:0][0:COUNT_ROP_WIDTH-1] upper_row_rop_count;
logic [MAX_COLS-1:0][0:COUNT_ROP_WIDTH-1] center_row_rop_count;
logic [MAX_COLS-1:0] center_row_rop_mask;

prev_row_stores #(
    .MAX_COLS(MAX_COLS),
    .COUNT_ROP_WIDTH(COUNT_ROP_WIDTH)
) prev_row_stores_i (
    .clk(tck),
    // Adjacent Columns Data
        .adj_col_last(adj_col_last),
        .adj_col_valid(adj_col_valid),
        .adj_col_rop_count(adj_col_rop_count),
        .adj_col_rop_mask(adj_col_rop_mask),
    // Adjacent Rows Data
        .row_index(row_index),
        .next_row(next_row),
        .upper_row_rop_count(upper_row_rop_count),
        .center_row_rop_count(center_row_rop_count),
        .center_row_rop_mask(center_row_rop_mask)
);

logic [RESULT_WIDTH-1:0] accessible_rop_count;
logic accessible_rop_valid;

accessible_rop_counter #(
    .MAX_COLS(MAX_COLS),
    .COUNT_ROP_WIDTH(COUNT_ROP_WIDTH),
    .RESULT_WIDTH(RESULT_WIDTH)
) accessible_rop_counter_i (
    .clk(tck),
    // Lower Row Adjacent Columns Data
        .adj_col_last(adj_col_last),
        .adj_col_valid(adj_col_valid),
        .adj_col_rop_count(adj_col_rop_count),
        .adj_col_rop_mask(adj_col_rop_mask),
    // Adjacent Rows Data
        .row_index(row_index),
        .next_row(next_row),
        .upper_row_rop_count(upper_row_rop_count),
        .center_row_rop_count(center_row_rop_count),
        .center_row_rop_mask(center_row_rop_mask),
    // Result
        .accessible_rop_count(accessible_rop_count),
        .accessible_rop_valid(accessible_rop_valid)
);

tap_encoder #(.DATA_WIDTH(16)) tap_encoder_i (
    // TAP signals
        .tck(tck),
        .tdo(tdo),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
    // Encoded signals
        .data(accessible_rop_count),
        .valid(1'b1)
);

endmodule
`default_nettype wire
