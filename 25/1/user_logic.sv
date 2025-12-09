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

localparam int DATA_WIDTH = 8;
typedef logic [DATA_WIDTH-1:0] data_t;
data_t inbound_data;
logic inbound_valid;

tap_decoder #(.DATA_WIDTH(DATA_WIDTH)) tap_decoder_i (
    // TAP signals
        .tck(tck),
        .tdi(tdi),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .shift_dr(shift_dr),
        .update_dr(update_dr),
    // Decoded signals
        .data(inbound_data),
        .valid(inbound_valid)
);

logic [DATA_WIDTH-1:0] right_steps;
logic right_steps_valid;

ascii_decoder ascii_decoder_i(
    .clk(tck),
    .ascii_data(inbound_data),
    .ascii_valid(inbound_valid),
    .right_steps(right_steps),
    .right_steps_valid(right_steps_valid)
);

logic [DATA_WIDTH-1:0] right_steps_acc;
logic right_steps_acc_valid;

always_ff @(posedge tck) begin: accumulate_modulo_100
    if (test_logic_reset) begin
        right_steps_acc <= 50;
        right_steps_acc_valid <= 1'b0;
    end else if (right_steps_valid) begin
        right_steps_acc_valid <= 1'b1;
        if (right_steps_acc + right_steps < 100) begin
            right_steps_acc <= right_steps_acc + right_steps;
        end else begin
            right_steps_acc <= right_steps_acc + right_steps - 100;
        end
    end else begin
        right_steps_acc_valid <= 1'b0;
    end
end

logic [16-1:0] zeroes;
logic [16-1:0] outbound_data;
logic outbound_valid;

always_ff @(posedge tck) begin: count_zeroes
    if (test_logic_reset) begin
        zeroes <= '0;
    end else if (right_steps_acc_valid) begin
        outbound_valid <= 1'b1;
        if (right_steps_acc == 0) begin
            zeroes <= zeroes + 1;
        end
    end else begin
        outbound_valid <= 1'b0;
    end
end

assign outbound_data = zeroes;

tap_encoder #(.DATA_WIDTH(16)) tap_encoder_i (
    // TAP signals
        .tck(tck),
        .tdo(tdo),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
    // Encoded signals
        .data(outbound_data),
        .valid(outbound_valid)
);

endmodule
`default_nettype wire
