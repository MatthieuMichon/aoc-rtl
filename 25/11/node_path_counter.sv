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

typedef logic [RESULT_WIDTH-1:0] path_count_t;
typedef logic [NODE_WIDTH-1:0] node_t;

path_count_t path_count[MAX_NODES-1:0];
path_count_t path_count_rd_data, path_count_wr_data;
logic root_node_cnt_valid, outdeg_node_cnt_valid;
path_count_t root_node_cnt, root_node_cnt_reg;
logic path_count_rd_en, path_count_wr_en;
node_t root_node, path_count_rd_addr, path_count_wr_addr;
logic start_node_registered = 1'b0;

logic query_ready, query_valid;
node_t query_data;
logic reply_last, reply_ready, reply_valid;
node_t reply_data;
logic reply_no_edges_found;

assign path_count_rd_en = (trimed_valid || reply_valid);
assign path_count_rd_addr = (trimed_valid) ? trimed_node : reply_data;

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

always_ff @(posedge clk) root_node_cnt_valid <= trimed_valid;
always_ff @(posedge clk) outdeg_node_cnt_valid <= reply_valid;

assign root_node_cnt = (root_node_cnt_valid) ? path_count_rd_data : root_node_cnt_reg;
always_ff @(posedge clk) root_node_cnt_reg <= root_node_cnt;

always_ff @(posedge clk) begin: path_count_update
    if (!start_node_registered && start_end_nodes_valid) begin
        path_count_wr_en <= 1'b1;
        path_count_wr_addr <= start_node_idx;
        path_count_wr_data <= 1;
        start_node_registered <= 1'b1;
    end else if (outdeg_node_cnt_valid) begin
        path_count_wr_en <= 1'b1;
        path_count_wr_addr <= path_count_rd_addr;
        path_count_wr_data <= root_node_cnt + path_count_rd_data;
    end else begin
        path_count_wr_en <= 1'b0;
    end
end

always_ff @(posedge clk) begin: root_node_update
    if (trimed_valid) begin
        root_node <= trimed_node;
    end
end

always_ff @(posedge clk) begin: result_capture
    if ((root_node == end_node_idx) && root_node_cnt_valid) begin
        path_count_value <= root_node_cnt;
        path_count_valid <= 1'b1;
    end
end

assign query_data = trimed_node;
assign query_valid = trimed_valid;
assign reply_ready = 1'b1;

adjacency_map adjacency_map_i (
    .clk(clk),
    // Connection Entries
        .decoding_done(decoding_done),
        .edge_valid(edge_valid),
        .src_node_valid(src_node_valid),
        .src_node(src_node),
        .dst_node(dst_node),
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

/* verilator lint_off UNUSEDSIGNAL */
wire _unused_ok = 1'b0 && &{1'b0,
    trimed_done,
    query_ready,
    reply_last,
    reply_no_edges_found,
    1'b0};
/* verilator lint_on UNUSEDSIGNAL */

endmodule
`default_nettype wire
