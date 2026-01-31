`timescale 1ns/1ps
`default_nettype none

module md5_engine #(
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

localparam int DIGEST_WIDTH = 128; // bits
typedef logic [DIGEST_WIDTH-1:0] digest_t;

logic digest_valid;
digest_t digest_data, filtered_digest_header;

md5_top md5_top_i (
    .clk(clk),
    .reset(reset),
    // Block Input
        .md5_block_ready(md5_block_ready),
        .md5_block_valid(md5_block_valid),
        .md5_block_data(md5_block_data),
    // Digest Output
        .digest_valid(digest_valid),
        .digest_data(digest_data)
);

// IMPORTANT: Assumes the number suffix completely fits in the first 128 bits

always_ff @(posedge clk) begin: capture_and_hold
    if (md5_block_ready) begin
        filtered_digest_header <= md5_block_data[BLOCK_WIDTH-1-:DIGEST_WIDTH];
    end
end

logic filtered_valid;
digest_t filtered_data;

hash_filter hash_filter_i (
    .clk(clk),
    .reset(reset),
    // Digest Input
        .digest_valid(digest_valid),
        .digest_data(digest_data),
    // Filtered Output
        .filtered_valid(filtered_valid),
        .filtered_data(filtered_data)
);

assign result_valid = filtered_valid;
assign result_data = filtered_digest_header;

wire _unused_ok = 1'b0 && &{1'b0,
    filtered_data,
    1'b0};

endmodule
`default_nettype wire
