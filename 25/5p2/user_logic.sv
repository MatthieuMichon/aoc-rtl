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

localparam int BYTE_WIDTH = 8;
// From design space exploration
localparam int RANGE_WIDTH = 49;
localparam int RANGE_CHECK_INSTANCES = 200;
localparam int RESULT_DATA_WIDTH = 16;

typedef logic [RANGE_WIDTH-1:0] id_range_data_t;
typedef logic [RESULT_DATA_WIDTH-1:0] result_data_t;

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
        .data(inbound_data),
        .valid(inbound_valid)
);

logic conf_done_array[0:RANGE_CHECK_INSTANCES];
logic valid_array[0:RANGE_CHECK_INSTANCES];
id_range_data_t data_array[0:RANGE_CHECK_INSTANCES];

input_decoder #(
    .RANGE_WIDTH(RANGE_WIDTH)
) input_decoder_i (
    .clk(tck),
    // Inbound Byte Stream
        .inbound_valid(inbound_valid),
        .inbound_byte(inbound_data),
    // Decoded signals
        .end_of_file(conf_done_array[0]),
        .range_valid(valid_array[0]),
        .range_data(data_array[0])
);

genvar i;
generate
    for (i = 0; i < RANGE_CHECK_INSTANCES; i++) begin : range_check_gen

        range_check #(
            .RANGE_WIDTH(RANGE_WIDTH)
        ) range_check_i (
            .clk(tck),
            // Upstream Range Check Unit
                .upstream_conf_done(conf_done_array[i]),
                .upstream_valid(valid_array[i]),
                .upstream_data(data_array[i]),
            // Downstream Range Check Unit
                .downstream_conf_done(conf_done_array[1+i]),
                .downstream_valid(valid_array[1+i]),
                .downstream_data(data_array[1+i])
        );

    end
endgenerate

result_data_t result_data;
logic result_valid;

initial begin
    result_valid = 1'b0;
    result_data = '0;
end

always_ff @(posedge tck) begin
    if (conf_done_array[$high(valid_array)]) begin
        result_valid <= 1'b1;
        result_data <= 16'hCAFE; // test purposes only
    end
end

tap_encoder #(.DATA_WIDTH(RESULT_DATA_WIDTH)) tap_encoder_i (
    .tck(tck),
    // Encoded signals
        .valid(result_valid),
        .data(result_data),
    // TAP signals
        .tdo(tdo),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr)
);

wire _unused_ok = 1'b0 && &{1'b0,
    run_test_idle,
    1'b0};

endmodule
`default_nettype wire
