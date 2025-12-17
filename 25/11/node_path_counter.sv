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
    // Matching Indexes for Start/End Nodes
        input wire [NODE_WIDTH-1:0] start_node_idx,
        input wire [NODE_WIDTH-1:0] end_node_idx,
        input wire start_end_nodes_valid,
    // Trimed Sorted Nodes
        input wire trimed_done,
        input wire trimed_valid,
        input wire [NODE_WIDTH-1:0] trimed_node,
    // Path Count
        output logic path_count_valid,
        output logic [RESULT_WIDTH-1:0] path_count_value
);

typedef logic [NODE_WIDTH-1:0] node_t;

/* Path Count */

typedef logic [RESULT_WIDTH-1:0] path_count_t;

path_count_t src_node_edge_count;
path_count_t path_count[MAX_NODES-1:0];
logic start_node_registered = 1'b0;
path_count_t path_count_rd_data, path_count_wr_data;
node_t path_count_rd_addr, path_count_wr_addr;
logic path_count_rd_en, path_count_wr_en;
logic prev_trimed_valid;

always_ff @(posedge clk) begin: path_count_read
    if (path_count_rd_en) begin: register_start_node
        path_count_rd_data <= path_count[path_count_rd_addr];
    end
end

always_ff @(posedge clk) begin: path_count_write
    if (path_count_wr_en) begin: register_start_node
        path_count[path_count_wr_addr] <= path_count_wr_data;
    end
end

assign path_count_rd_addr = trimed_node;
assign path_count_rd_en = 1'b1;

always_ff @(posedge clk) begin
    if (prev_trimed_valid) begin
        src_node_edge_count <= path_count_rd_data;
    end
    prev_trimed_valid <= trimed_valid;
end

always_ff @(posedge clk) begin: path_count_update
    if (!start_node_registered && start_end_nodes_valid) begin
        path_count_wr_en <= 1'b1;
        path_count_wr_addr <= start_node_idx;
        path_count_wr_data <= 1;
        start_node_registered <= 1'b1;
    end else begin
        path_count_wr_en <= 1'b0;
        path_count_wr_addr <= 0;
        path_count_wr_data <= 0;
    end
end

 /* Adjacency List */

logic query_ready;
logic query_valid = 1'b0;
node_t query_data = '0;
logic reply_ready = 1'b0;
logic reply_valid;
logic reply_last;
node_t reply_data;
logic reply_no_edges_found;

always_ff @(posedge clk) begin
    if (!reply_ready) begin
        reply_ready <= trimed_valid;
    end else begin
        reply_ready <= (reply_ready && !(reply_last && reply_valid));
    end
end

assign query_data = trimed_node;
assign query_valid = trimed_valid;

adjacency_map adjacency_map_i (
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

wire _unused_ok = 1'b0 && &{1'b0,
    src_node_edge_count,
    path_count_rd_data,
    end_node_idx,
    trimed_node,
    query_ready,
    query_valid,
    query_data,
    reply_ready,
    reply_valid,
    reply_last,
    reply_data,
    reply_no_edges_found,
    1'b0};

endmodule
`default_nettype wire
