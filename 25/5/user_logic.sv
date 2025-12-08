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

localparam int BYTE_WIDTH = 8;
// From design space exploration
localparam int INGREDIENT_ID_RANGE_WIDTH = 49;
localparam int RANGE_CHECK_INSTANCES = 200;
localparam int MAX_INGREDIENT_QTY = 1000;

localparam int RESULT_DATA_WIDTH = $clog2(MAX_INGREDIENT_QTY);

typedef logic [INGREDIENT_ID_RANGE_WIDTH-1:0] id_range_data_t;

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

logic sel_array[0:RANGE_CHECK_INSTANCES];
logic valid_array[0:RANGE_CHECK_INSTANCES];
id_range_data_t data_array[0:RANGE_CHECK_INSTANCES];

input_decoder #(
    .INGREDIENT_ID_RANGE_WIDTH(INGREDIENT_ID_RANGE_WIDTH)
) input_decoder_i (
    .clk(tck),
    // Inbound Byte Stream
        .byte_valid(inbound_valid),
        .byte_data(inbound_data),
    // Decoded signals
        .id_range_sel(sel_array[0]),
        .id_range_valid(valid_array[0]),
        .id_range_data(data_array[0])
);

genvar i;
generate
    for (i = 0; i < RANGE_CHECK_INSTANCES; i++) begin : range_check_gen

        range_check #(
            .INGREDIENT_ID_RANGE_WIDTH(INGREDIENT_ID_RANGE_WIDTH)
        ) range_check_i (
            .clk(tck),
            // Upstream Range Check Unit
                .upstream_id_range_sel(sel_array[i]),
                .upstream_id_range_valid(valid_array[i]),
                .upstream_id_range_data(data_array[i]),
            // Downstream Range Check Unit
                .downstream_id_range_sel(sel_array[1+i]),
                .downstream_id_range_valid(valid_array[1+i]),
                .downstream_id_range_data(data_array[1+i])
        );

    end
endgenerate

logic [RESULT_DATA_WIDTH-1:0] result_data;
logic result_valid;

initial result_data = '0;
always_ff @(posedge tck) begin: count_ingredients
    if (valid_array[$size(valid_array)-1]) begin
        result_data <= result_data + 1;
        result_valid <= 1'b1;
    end else begin
        result_valid <= 1'b0;
    end
end

tap_encoder #(.DATA_WIDTH(RESULT_DATA_WIDTH)) tap_encoder_i (
    // TAP signals
        .tck(tck),
        .tdo(tdo),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
    // Encoded signals
        .data(result_data),
        .valid(result_valid)
);

endmodule
`default_nettype wire
