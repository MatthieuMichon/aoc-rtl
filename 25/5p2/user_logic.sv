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
localparam int RESULT_DATA_WIDTH = 64;
localparam int ID_WIDTH = 49;
localparam int RANGE_CHECK_INSTANCES = 200;

typedef logic [ID_WIDTH-1:0] id_t;
typedef logic [RESULT_DATA_WIDTH-1:0] result_data_t;

logic inbound_valid;
logic [BYTE_WIDTH-1:0] inbound_byte;

tap_decoder #(.DATA_WIDTH(BYTE_WIDTH)) tap_decoder_i (
    // TAP signals
        .tck(tck),
        .tdi(tdi),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .shift_dr(shift_dr),
        .update_dr(update_dr),
    // Decoded signals
        .data(inbound_byte),
        .valid(inbound_valid)
);

logic [RANGE_CHECK_INSTANCES:0] dump_done_array;
logic [RANGE_CHECK_INSTANCES:0] conf_done_array;
logic [RANGE_CHECK_INSTANCES:0] valid_array;
id_t lower_id_array[0:RANGE_CHECK_INSTANCES], upper_id_array[0:RANGE_CHECK_INSTANCES];

line_decoder #(.ID_WIDTH(ID_WIDTH)) input_decoder_i (
    .clk(tck),
    // Inbound Byte Stream
        .inbound_valid(inbound_valid),
        .inbound_byte(inbound_byte),
    // Decoded signals
        .end_of_file(conf_done_array[0]),
        .range_valid(valid_array[0]),
        .lower_id(lower_id_array[0]),
        .upper_id(upper_id_array[0])
);

always_ff @(posedge tck) dump_done_array[0] <= conf_done_array[0];

genvar i;
generate
    for (i = 0; i < RANGE_CHECK_INSTANCES; i++) begin : range_check_gen

        range_check #(
            .ID_WIDTH(ID_WIDTH)
        ) range_check_i (
            .clk(tck),
            // Upstream Range Check Unit
                .upstream_dump_done(dump_done_array[i]),
                .upstream_conf_done(conf_done_array[i]),
                .upstream_valid(valid_array[i]),
                .upstream_lower_id(lower_id_array[i]),
                .upstream_upper_id(upper_id_array[i]),
            // Downstream Range Check Unit
                .downstream_dump_done(dump_done_array[1+i]),
                .downstream_conf_done(conf_done_array[1+i]),
                .downstream_valid(valid_array[1+i]),
                .downstream_lower_id(lower_id_array[1+i]),
                .downstream_upper_id(upper_id_array[1+i])
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
    result_valid <= dump_done_array[$high(dump_done_array)];
    if (valid_array[$high(valid_array)]) begin
        result_data <= result_data +
            1 +
            RESULT_DATA_WIDTH'(upper_id_array[$high(upper_id_array)]) -
            RESULT_DATA_WIDTH'(lower_id_array[$high(lower_id_array)]);
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
    conf_done_array,
    run_test_idle,
    1'b0};

endmodule
`default_nettype wire
