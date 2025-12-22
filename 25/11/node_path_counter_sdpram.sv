`timescale 1ns/1ps
`default_nettype none

module node_path_counter_sdpram #(
    parameter int MAX_NODES = 1024,
    parameter int RESULT_WIDTH = 16,
    parameter int NODE_WIDTH = $clog2(MAX_NODES)
)(
    input wire clk,
    input wire path_count_rd_en,
    input wire path_count_wr_en,
    input wire [NODE_WIDTH-1:0] path_count_rd_addr,
    input wire [NODE_WIDTH-1:0] path_count_wr_addr,
    input wire [RESULT_WIDTH-1:0] path_count_wr_data,
    output logic [RESULT_WIDTH-1:0] path_count_rd_data
);

typedef logic [RESULT_WIDTH-1:0] path_count_t;
path_count_t path_count[2**NODE_WIDTH-1:0];

always_ff @(posedge clk) begin: path_count_write
    if (path_count_wr_en) begin
        path_count[path_count_wr_addr] <= path_count_wr_data;
    end
end

always_ff @(posedge clk) begin: path_count_read
    if (path_count_rd_en) begin
        path_count_rd_data <= path_count[path_count_rd_addr];
    end
end

endmodule
`default_nettype wire
