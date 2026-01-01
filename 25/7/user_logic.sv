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
localparam int LINE_WIDTH = 160;
localparam int RESULT_WIDTH = 16;

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

logic end_of_file;
logic line_valid;
logic [LINE_WIDTH-1:0] line_data;

line_decoder #(.LINE_WIDTH(LINE_WIDTH)) line_decoder_i (
    .clk(tck),
    // Input byte stream
        .inbound_data(inbound_data),
        .inbound_valid(inbound_valid),
    // Decoded line
        .end_of_file(end_of_file),
        .line_valid(line_valid),
        .line_data(line_data)
);

logic active_splitters_valid;
logic [LINE_WIDTH-1:0] active_splitters_data;

beam_tracker #(.LINE_WIDTH(LINE_WIDTH)) beam_tracker_i (
    .clk(tck),
    // Input byte stream
        .line_valid(line_valid),
        .line_data(line_data),
    // Active splitters
        .active_splitters_valid(active_splitters_valid),
        .active_splitters_data(active_splitters_data)
);

logic outbound_valid;
logic [RESULT_WIDTH-1:0] outbound_data = '0;

always_ff @(posedge tck) begin
    if (test_logic_reset) begin
        outbound_valid <= 1'b0;
        outbound_data <= '0;
    end else begin
        outbound_valid <= end_of_file;
        if (active_splitters_valid) begin
            outbound_data <= outbound_data + $countones(active_splitters_data);
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
    end_of_file,
    line_data,
    run_test_idle,
    test_logic_reset,
    run_test_idle,
    ir_is_user,
    capture_dr,
    shift_dr,
    update_dr, tck,
    active_splitters_valid,
    active_splitters_data,
    inbound_valid,
    inbound_data,
    1'b0};
endmodule
`default_nettype wire
