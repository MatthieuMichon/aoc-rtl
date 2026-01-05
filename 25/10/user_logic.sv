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
localparam int MAX_WIRING_WIDTH = 10;
localparam int MAX_BUTTON_WIRINGS = 13;
localparam int RESULT_WIDTH = 16;

typedef logic [MAX_WIRING_WIDTH-1:0] wiring_t;
typedef logic [MAX_BUTTON_WIRINGS-1:0] button_wirings_t;
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

logic end_of_file, end_of_line, wiring_valid;
wiring_t wiring_data;

line_decoder #(.MAX_WIRING_WIDTH(MAX_WIRING_WIDTH)) line_decoder_i (
    .clk(tck),
    // Inbound Byte Stream
        .inbound_valid(inbound_valid),
        .inbound_byte(inbound_data),
    // Decoded Line Contents
        .end_of_file(end_of_file), // held high
        .end_of_line(end_of_line),
        .wiring_valid(wiring_valid),
        .wiring_data(wiring_data)
);

logic compute_finished, result_valid;
result_t result_data;

machine_compute_units #(
    .MAX_WIRING_WIDTH(MAX_WIRING_WIDTH),
    .MAX_BUTTON_WIRINGS(MAX_BUTTON_WIRINGS),
    .RESULT_WIDTH(RESULT_WIDTH)
) machine_compute_units_i (
    .clk(tck),
    // Decoded Line Contents
        .end_of_file(end_of_file),
        .end_of_line(end_of_line),
        .wiring_valid(wiring_valid),
        .wiring_data(wiring_data),
    // Solver Outputs
        .compute_finished(compute_finished),
        .result_valid(result_valid),
        .result_data(result_data)
);

logic outbound_valid;
logic [RESULT_WIDTH-1:0] outbound_data = '0;

always_ff @(posedge tck) begin
    if (test_logic_reset) begin
        outbound_valid <= 1'b0;
        outbound_data <= '0;
    end else begin
        outbound_valid <= compute_finished;
        if (result_valid) begin
            outbound_data <= outbound_data + result_data;
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
    1'b0};
endmodule
`default_nettype wire
