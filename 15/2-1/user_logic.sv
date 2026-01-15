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
localparam int SIZE_WIDTH = 8;
localparam int RESULT_WIDTH = 32;

typedef logic [SIZE_WIDTH-1:0] size_t;
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
    // Inbound signals
        .valid(inbound_valid),
        .data(inbound_data));

logic end_of_file, size_valid;
size_t length, width, height;

line_decoder #(.SIZE_WIDTH(SIZE_WIDTH)) line_decoder_i (
    .clk(tck),
    .reset(test_logic_reset),
    // Inbound Byte Stream
        .inbound_valid(inbound_valid),
        .inbound_byte(inbound_data),
    // Decoded Line Contents
        .end_of_file(end_of_file), // held high
        .size_valid(size_valid),
        .length(length),
        .width(width),
        .height(height));

logic area_valid;
result_t area_value;

area_compute #(
    .SIZE_WIDTH(SIZE_WIDTH),
    .AREA_WIDTH(RESULT_WIDTH)
) area_compute_i (
    .clk(tck),
    // Dimensions
        .size_valid(size_valid),
        .length(length),
        .width(width),
        .height(height),
    // Computed Values
        .area_valid(area_valid),
        .area_value(area_value));

logic outbound_valid;
logic [RESULT_WIDTH-1:0] outbound_data = '0;

always_ff @(posedge tck) begin: scaffolding
    if (area_valid) begin
        outbound_data <= outbound_data + area_value;
    end
    outbound_valid <= end_of_file;
end

tap_encoder #(.DATA_WIDTH(RESULT_WIDTH)) tap_encoder_i (
    .tck(tck),
    // Encoded signals
        .valid(outbound_valid),
        .data(outbound_data),
    // TAP signals
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
        .tdo(tdo)
);

wire _unused_ok = 1'b0 && &{1'b0,
    length, width, height,
    run_test_idle,
    1'b0};

endmodule
`default_nettype wire
