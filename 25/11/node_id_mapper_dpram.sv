`timescale 1ns/1ps
`default_nettype none

module node_id_mapper_dpram #(
    parameter int NODE_STR_WIDTH = 15, // do not override
    parameter int MAX_NODES = 1024,
    parameter int NODE_IDX_WIDTH = $clog2(MAX_NODES)
)(
    input wire clk,

    input wire node_lut_src_wr_en,
    input wire node_lut_dst_wr_en,
    input wire [NODE_STR_WIDTH-1:0] src_node_str,
    input wire [NODE_STR_WIDTH-1:0] dst_node_str,
    input wire [1+NODE_IDX_WIDTH-1:0] node_lut_src_wr_data,
    input wire [1+NODE_IDX_WIDTH-1:0] node_lut_dst_wr_data,
    output logic [1+NODE_IDX_WIDTH-1:0] node_lut_src_rd_data,
    output logic [1+NODE_IDX_WIDTH-1:0] node_lut_dst_rd_data
);

typedef logic [1+NODE_IDX_WIDTH-1:0] flat_entry_t;
flat_entry_t node_lut[2**NODE_STR_WIDTH-1:0];

always_ff @(posedge clk) begin: port_a
    if (node_lut_src_wr_en) begin
        node_lut[src_node_str] <= node_lut_src_wr_data;
    end
    node_lut_src_rd_data <= node_lut[src_node_str];
end

always_ff @(posedge clk) begin: port_b
    if (node_lut_dst_wr_en) begin
        node_lut[dst_node_str] <= node_lut_dst_wr_data;
    end
    node_lut_dst_rd_data <= node_lut[dst_node_str];
end

endmodule
`default_nettype wire
