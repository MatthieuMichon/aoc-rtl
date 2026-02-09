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
        input wire update_dr,
    // 'fast' clock
        input wire conf_clk
);

localparam int RESULT_WIDTH = 24;
localparam int UPSTREAM_BYPASS_BITS = 1; // ARM DAP controller in BYPASS mode
localparam int INBOUND_DATA_WIDTH = $bits(byte);
localparam int INSTRUCTION_WIDTH = 2 + 4 * 12 + 2;

typedef logic [INBOUND_DATA_WIDTH-1:0] inbound_data_t;
typedef logic [INSTRUCTION_WIDTH-1:0] instr_t;
typedef logic [RESULT_WIDTH-1:0] result_t;

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
logic end_of_file, normalized_instr_valid;
instr_t normalized_instr_data;

assign reset = test_logic_reset || !ir_is_user;

line_decoder #(
    .INBOUND_DATA_WIDTH(INBOUND_DATA_WIDTH),
    .INSTRUCTION_WIDTH(INSTRUCTION_WIDTH)
) line_decoder_i (
    .clk(tck),
    .reset(reset),
    // Deserialized Data
        .inbound_valid(inbound_valid),
        .inbound_data(inbound_data),
    // Normalized Data
        .end_of_file(end_of_file),
        .normalized_instr_valid(normalized_instr_valid),
        .normalized_instr_data(normalized_instr_data)
);

logic outbound_valid_tck;
result_t outbound_data = '0;

always_ff @(posedge tck) begin
    outbound_valid_tck <= end_of_file;
    if (normalized_instr_valid) begin
        outbound_data <= outbound_data + $countones(normalized_instr_data);
    end
end

tap_encoder #(
    .OUTBOUND_DATA_WIDTH(RESULT_WIDTH)
) tap_encoder_i (
    // Deserialized Signals
        .outbound_valid(outbound_valid_tck),
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
    conf_clk,
    inbound_alignment_error,
    normalized_instr_data,
    1'b0};

endmodule
`default_nettype wire
