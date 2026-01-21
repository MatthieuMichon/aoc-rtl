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

localparam int INBOUND_DATA_WIDTH = $bits(byte);
typedef logic [INBOUND_DATA_WIDTH-1:0] inbound_data_t;
typedef logic [RESULT_WIDTH-1:0] result_t;

logic inbound_alignment_error;
logic inbound_valid;
inbound_data_t inbound_data;

tap_decoder #(
    .INBOUND_DATA_WIDTH(INBOUND_DATA_WIDTH)
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

logic outbound_valid;
result_t outbound_data = '0;

always_ff @(posedge tck) begin: shift_logic_on_negedge
    if (test_logic_reset) begin
        outbound_data <= '0;
    end else if (inbound_valid) begin
        outbound_valid <= (inbound_data == 8'h0A);
        outbound_data <= outbound_data + 1'b1;
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
    inbound_alignment_error,
    run_test_idle,

    1'b0};

endmodule
`default_nettype wire
