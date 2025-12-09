`timescale 1ns/1ps
`default_nettype none

module user_logic (
    input wire tck,
    input wire tdi,
    output logic tdo,
    input wire test_logic_reset,
    input wire ir_is_user,
    input wire capture_dr,
    input wire shift_dr,
    input wire update_dr
);

localparam int BYTE_WIDTH = $bits(byte);
// From design space exploration

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

logic count_last;
logic count_valid;
logic [COUNT_ROP_WIDTH-1:0] count_rop;

adjacent_rop_counter #(.COUNT_ROP_WIDTH(COUNT_ROP_WIDTH))
adjacent_rop_counter_i (
    .clk(tck),
    // Binary row data
        .bin_last(cell_last),
        .bin_valid(cell_valid),
        .bin_rop(cell_rop),
    // Adjacent ROP row data
        .count_last(count_last),
        .count_valid(count_valid),
        .count_rop(count_rop)
);

// logic [16-1:0] cell_cnt;

// always_ff @(posedge tck) begin
//     if (cell_valid && cell_rop) begin
//         cell_cnt <= cell_cnt + 1;
//     end
// end

tap_encoder #(.DATA_WIDTH(16)) tap_encoder_i (
    // TAP signals
        .tck(tck),
        .tdo(tdo),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
    // Encoded signals
        .data(count_rop),
        .valid(1'b1)
);

endmodule
`default_nettype wire
