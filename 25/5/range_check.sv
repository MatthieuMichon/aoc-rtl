`timescale 1ns/1ps
`default_nettype none

module range_check #(
    parameter int INGREDIENT_ID_RANGE_WIDTH
)(
    input wire clk,
    // Upstream Range Check Unit
        input wire upstream_id_range_sel,  // 1: ingredient ID, 0: range
        input wire upstream_id_range_valid,
        input wire [INGREDIENT_ID_RANGE_WIDTH-1:0] upstream_id_range_data,
    // Downstream Range Check Unit
        output logic downstream_id_range_sel,  // 1: ingredient ID, 0: range
        output logic downstream_id_range_valid,
        output logic [INGREDIENT_ID_RANGE_WIDTH-1:0] downstream_id_range_data
);

assign downstream_id_range_sel = upstream_id_range_sel;
assign downstream_id_range_valid = upstream_id_range_valid;
assign downstream_id_range_data = upstream_id_range_data;

endmodule
`default_nettype wire
