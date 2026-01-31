`timescale 1ns/1ps
`default_nettype none

module md5_engine_units #(
    parameter int BLOCK_WIDTH = 512, // bits
    parameter int RESULT_WIDTH
) (
    input wire clk,
    input wire reset,
    // Block Input
        output logic md5_block_ready,
        input wire md5_block_valid,
        input wire [BLOCK_WIDTH-1:0] md5_block_data,
    // Digest Output
        output logic result_valid,
        output logic [RESULT_WIDTH-1:0] result_data
);

localparam int MD5_TOP_UNITS = 7;

typedef logic [BLOCK_WIDTH-1:0] md5_block_t;
typedef logic [RESULT_WIDTH-1:0] result_t;
typedef logic [MD5_TOP_UNITS-1:0] md5_units_t;

logic handshake_occured;
md5_units_t per_unit_sel = MD5_TOP_UNITS'(1);
md5_units_t per_unit_block_ready, per_unit_result_valid;
result_t per_unit_result_data [0:MD5_TOP_UNITS-1];

logic block_header_valid;
logic [RESULT_WIDTH-1:0] block_header_data = '0;

assign md5_block_ready = |(per_unit_block_ready & per_unit_sel);
assign handshake_occured = md5_block_ready && md5_block_valid;

always_ff @(posedge clk) begin : dispatch_to_units
    if (handshake_occured) begin: select_next_unit
        per_unit_sel <= {per_unit_sel[MD5_TOP_UNITS-2:0], per_unit_sel[MD5_TOP_UNITS-1]};
    end
end

genvar i; generate for (i=0; i<MD5_TOP_UNITS; i++) begin: per_md5_top

    md5_engine #(
        .BLOCK_WIDTH(BLOCK_WIDTH), // bits
        .RESULT_WIDTH(RESULT_WIDTH)
    ) md5_engine_i (
        .clk(clk),
        .reset(reset),
        // Block Input
            .md5_block_ready(per_unit_block_ready[i]),
            .md5_block_valid(per_unit_sel[i] & md5_block_valid),
            .md5_block_data(md5_block_data),
        // Digest Output
            .result_valid(per_unit_result_valid[i]),
            .result_data(per_unit_result_data[i])
    );

end endgenerate

// Works because only one engine will match the correct result

always_ff @(posedge clk) begin
    block_header_valid <= 1'b0;
    for (int j = 0; j < MD5_TOP_UNITS; j++) begin
        if (per_unit_result_valid[j]) begin
            block_header_valid <= 1'b1;
            block_header_data <= per_unit_result_data[j];
        end
    end
end

suffix_extractor #(
    .BLOCK_HEADER_WIDTH(RESULT_WIDTH),
    .RESULT_WIDTH(RESULT_WIDTH)
)suffix_extractor_i (
    .clk(clk),
    .reset(reset),
    // Filtered Input
        .block_header_valid(block_header_valid),
        .block_header_data(block_header_data),
    // Suffix Output
        .result_valid(result_valid),
        .result_data(result_data)
);

endmodule
`default_nettype wire
