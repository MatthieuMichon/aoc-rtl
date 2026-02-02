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

typedef logic [RESULT_WIDTH-1:0] result_t;
typedef logic [INBOUND_DATA_WIDTH-1:0] inbound_data_t;

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

logic reset;
assign reset = test_logic_reset || !ir_is_user;

logic end_of_file, string_is_nice;

string_filter #(
    .INBOUND_DATA_WIDTH(INBOUND_DATA_WIDTH)
) string_filter_i (
    .clk(tck),
    .reset(reset),
    // Deserialized Data
        .inbound_valid(inbound_valid),
        .inbound_data(inbound_data),
    // Result Data
        .end_of_file(end_of_file),
        .string_is_nice(string_is_nice)
);

logic outbound_valid;
result_t outbound_data = '0;

always_ff @(posedge tck) begin
    if (reset) begin
        outbound_valid <= 1'b0;
    end else begin
        outbound_valid <= end_of_file;
        if (string_is_nice) begin
            outbound_data <= outbound_data + 1'b1;
        end
    end
end

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
    run_test_idle,
    inbound_alignment_error,
    1'b0};

endmodule
`default_nettype wire
