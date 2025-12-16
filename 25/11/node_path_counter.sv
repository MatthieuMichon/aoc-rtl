`timescale 1ns/1ps
`default_nettype none

module node_path_counter #(
    parameter int MAX_NODES = 1024,
    parameter int RESULT_WIDTH = 16,
    parameter int NODE_WIDTH = $clog2(MAX_NODES)
)(
    input wire clk,
    // Adjacency Nodes Entries
        input wire decoding_done,
        input wire edge_valid,
        input wire src_node_valid, // for early src_node LUT registration
        input wire [NODE_WIDTH-1:0] src_node,
        input wire [NODE_WIDTH-1:0] dst_node,
        input wire [NODE_WIDTH-1:0] node_idx_cnt,
    // Trimed Sorted Nodes
        input wire trimed_done,
        input wire trimed_valid,
        input wire [NODE_WIDTH-1:0] trimed_node,
    // Path Count
        output logic path_count_valid,
        output logic [RESULT_WIDTH-1:0] path_count_value
);

typedef logic [NODE_WIDTH-1:0] node_t;

logic query_ready;
logic query_valid;
node_t query_data;
logic reply_ready;
logic reply_valid;
logic reply_last;
node_t reply_data;
logic reply_no_edges_found;

adjacency_map adjacency_map_i(
    .clk(clk),
    // Connection Entries
        .decoding_done(decoding_done),
        .edge_valid(edge_valid),
        .src_node_valid(src_node_valid),
        .src_node(src_node),
        .dst_node(dst_node),
        .node_idx_cnt(node_idx_cnt),
    // Query/Reply Interface
        .query_ready(query_ready),
        .query_valid(query_valid),
        .query_data(query_data),
        .reply_ready(reply_ready),
        .reply_valid(reply_valid),
        .reply_last(reply_last),
        .reply_data(reply_data),
        .reply_no_edges_found(reply_no_edges_found)
);






always_ff @(posedge clk) begin: dummy_test_logic
    path_count_valid <= 1'b0;
    if (trimed_valid) begin
        path_count_value <= path_count_value + 1'b1;
    end else if (trimed_done) begin
        path_count_valid <= 1'b1;
    end
end

endmodule
`default_nettype wire
