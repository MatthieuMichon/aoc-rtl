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
localparam int GRID_BITS = 18;
localparam int MAX_TILES = 512;
localparam int RESULT_WIDTH = 40;

typedef logic [GRID_BITS-1:0] position_t;
typedef logic [2*GRID_BITS-1:0] area_t;
typedef logic [RESULT_WIDTH-1:0] result_t;

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

logic end_of_file, tile_valid;
position_t tile_row, tile_col;

line_decoder #(.GRID_BITS(GRID_BITS)) line_decoder_i (
    .clk(tck),
    // Inbound Byte Stream
        .inbound_valid(inbound_valid),
        .inbound_byte(inbound_data),
    // Decoded Line Contents
        .end_of_file(end_of_file), // held high
        .tile_valid(tile_valid),
        .tile_row(tile_row),
        .tile_col(tile_col)
);

logic area_done, area_valid;
area_t area_data;

tile_store #(
    .GRID_BITS(GRID_BITS),
    .MAX_TILES(MAX_TILES)
) tile_store_i (
    .clk(tck),
    // Decoded Line Contents
        .end_of_file(end_of_file), // held high
        .tile_valid(tile_valid),
        .tile_row(tile_row),
        .tile_col(tile_col),
    // Tile Areas
        .area_done(area_done),
        .area_valid(area_valid),
        .area_data(area_data)
);

logic outbound_valid;
logic [RESULT_WIDTH-1:0] outbound_data = '0;

always_ff @(posedge tck) begin
    if (test_logic_reset) begin
        outbound_valid <= 1'b0;
        outbound_data <= '0;
    end else begin
        outbound_valid <= area_done;
        if (area_valid) begin
            if (RESULT_WIDTH'(area_data) > outbound_data) begin
                outbound_data <= RESULT_WIDTH'(area_data);
            end
        end
    end
end

tap_encoder #(.DATA_WIDTH(RESULT_WIDTH)) tap_encoder_i (
    // Encoded signals
        .valid(outbound_valid),
        .data(outbound_data),
    // TAP signals
        .tck(tck),
        .tdo(tdo),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr)
);

wire _unused_ok = 1'b0 && &{1'b0,
    run_test_idle, test_logic_reset,
    area_data,
    1'b0};
endmodule
`default_nettype wire
