`timescale 1ns/1ps
`default_nettype none

module user_logic (
    // TAP Controller Raw JTAG signals
        input wire tck,
        input wire tms,
        input wire tdi,
        output logic tdo,
    // TAP Controller States
        input wire test_logic_reset,
        input wire ir_is_user,
        input wire run_test_idle,
        input wire capture_dr,
        input wire shift_dr,
        input wire update_dr
);

localparam int RESULT_WIDTH = 16;

localparam int UPSTREAM_BYPASS_BITS = 1; // ARM DAP controller in BYPASS mode
localparam int INBOUND_DATA_WIDTH = $bits(byte);
localparam int POSTION_WIDTH = 8;

typedef logic [INBOUND_DATA_WIDTH-1:0] inbound_data_t;
typedef logic [RESULT_WIDTH-1:0] result_t;
typedef logic [POSTION_WIDTH-1:0] position_t;

logic inbound_alignment_error;
logic inbound_valid;
inbound_data_t inbound_data;

tap_decoder #(
    .INBOUND_DATA_WIDTH(INBOUND_DATA_WIDTH),
    .UPSTREAM_BYPASS_BITS(UPSTREAM_BYPASS_BITS)
) tap_decoder_i (
    // JTAG TAP Controller Signals
        .tck(tck),
        .tms(tms),
        .tdi(tdi),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .shift_dr(shift_dr),
        .update_dr(update_dr),
    // Deserialized Data
        .inbound_alignment_error(inbound_alignment_error),
        .inbound_valid(inbound_valid),
        .inbound_data(inbound_data)
);

logic end_of_file;
logic shift_valid;
logic [4-1:0] shift_direction; // one-hot: NESW

char_decoder #(.INBOUND_DATA_WIDTH(INBOUND_DATA_WIDTH)) char_decoder_i (
    .clk(tck),
    .reset(test_logic_reset),
    // Deserialized Data
        .inbound_valid(inbound_valid),
        .inbound_data(inbound_data),
    // Decoded Data
        .end_of_file(end_of_file),
        .shift_valid(shift_valid),
        .shift_direction(shift_direction)
);

logic pos_error, pos_change;
position_t pos_x, pos_y;

position_tracker #(
    .POSTION_WIDTH(POSTION_WIDTH)
) position_tracker_i (
    .clk(tck),
    .reset(test_logic_reset),
    // Decoded Data
        .shift_valid(shift_valid),
        .shift_direction(shift_direction),
    // Position Data
        .pos_error(pos_error),
        .pos_change(pos_change),
        .pos_x(pos_x),
        .pos_y(pos_y)
);

logic lookup_valid, lookup_already_visited;

visited_positions  #(
    .POSTION_WIDTH(POSTION_WIDTH)
) visited_positions_i (
    .clk(tck),
    .reset(test_logic_reset),
    // Position Data
        .pos_change(pos_change),
        .pos_x(pos_x),
        .pos_y(pos_y),
    // Visited Data
        .lookup_valid(lookup_valid),
        .lookup_already_visited(lookup_already_visited) // 1: already visited previously, 0: newly visited
);

logic outbound_valid;
result_t visited_houses, outbound_data;

always_ff @(posedge tck) begin: shift_logic_on_negedge
    if (test_logic_reset) begin
        outbound_valid <= 1'b0;
        visited_houses <= '0;
    end else begin
        outbound_valid <= end_of_file;
        if (lookup_valid) begin
            visited_houses <= (!lookup_already_visited) ? visited_houses + 1'b1 : visited_houses;
        end
    end
end

assign outbound_data = 1 + visited_houses;

tap_encoder #(
    .OUTBOUND_DATA_WIDTH(RESULT_WIDTH)
) tap_encoder_i (
    // Deserialized Signals
        .outbound_valid(outbound_valid),
        .outbound_data(outbound_data),
    // JTAG TAP Controller Signals
        .tck(tck),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
        .tdo(tdo)
);

wire _unused_ok = 1'b0 && &{1'b0,
    inbound_alignment_error,
    pos_error, lookup_valid,
    run_test_idle,
    1'b0};

endmodule
`default_nettype wire
