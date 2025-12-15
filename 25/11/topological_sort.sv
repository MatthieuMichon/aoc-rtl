`timescale 1ns/1ps
`default_nettype none

module topological_sort #(
    parameter int MAX_NODES = 1024,
    parameter int MAX_EDGES = 2048,
    parameter int NODE_WIDTH = $clog2(MAX_NODES)
)(
    input wire clk,
    // Connection Entries
        input wire decoding_done,
        input wire edge_valid,
        input wire src_node_valid, // for early src_node LUT registration
        input wire [NODE_WIDTH-1:0] src_node,
        input wire [NODE_WIDTH-1:0] dst_node,
        input wire [NODE_WIDTH-1:0] node_idx_cnt,
    // Indegree List Interface
        output logic [NODE_WIDTH-1:0] indeg_node,
        output logic indeg_dec,
        input wire [NODE_WIDTH-1:0] indeg_degree,
    // Query/Reply Interface
        input wire query_ready,
        output logic query_valid,
        output logic [NODE_WIDTH-1:0] query_data,
        output logic reply_ready,
        input wire reply_valid,
        input wire reply_last,
        input wire [NODE_WIDTH-1:0] reply_data
);

localparam int EDGE_ADDR_WIDTH = $clog2(MAX_EDGES);
typedef logic [NODE_WIDTH-1:0] node_t;
typedef logic [EDGE_ADDR_WIDTH-1:0] edge_addr_t;

// node_t in_degree_table [MAX_NODES-1:0] = '{default: 0};
// node_t incoming_edges;
// logic edge_valid_r;
// node_t dst_node_r;

// always_ff @(posedge clk) begin: readback
//     if (edge_valid) begin
//         incoming_edges <= in_degree_table[dst_node];
//     end
//     edge_valid_r <= edge_valid;
//     dst_node_r <= dst_node;
// end

// always_ff @(posedge clk) begin: update
//     if (edge_valid_r) begin
//         in_degree_table[dst_node_r] <= incoming_edges + 1;
//     end
// end

node_t empty_nodes_fifo[MAX_NODES-1:0];
node_t dst_node_cnt = '0, wr_ptr = '0, rd_ptr = '0, indeg_node_r = '0;
logic sweep_pending = 1'b0;

always_ff @(posedge clk) begin
    if (edge_valid) begin
        dst_node_cnt <= dst_node_cnt + 1;
    end
end

always_ff @(posedge clk) begin: initial_zero_indegree_sweep
    if (decoding_done || sweep_pending) begin
        sweep_pending <= 1'b1;
        if (indeg_node < node_idx_cnt) begin
            indeg_node <= indeg_node + 1;
        end else begin
            sweep_pending <= 1'b0;
        end
    end
    indeg_node_r <= indeg_node;
end

always_ff @(posedge clk) begin
    if (sweep_pending) begin
        if (!|indeg_degree) begin: initial_zero_indegree_node
            empty_nodes_fifo[wr_ptr] <= indeg_node_r;
            wr_ptr <= wr_ptr + 1;
        end
    end
end

assign indeg_dec = 1'b0;

// node_t sorted_nodes[MAX_NODES-1:0];
// node_t root_node;
// node_t sorted_nodes_ptr = '0;

// while queue:
//     top = queue.popleft()
//     res.append(top)
//     for next_node in adj[top]:
//         indegree[next_node] -= 1
//         if indegree[next_node] == 0:
//             queue.append(next_node)

// always_ff @(posedge clk) begin: kahns_algorithm
//     if (wr_ptr > rd_ptr) begin
//         root_node <= empty_nodes_fifo[rd_ptr];
//         sorted_nodes[sorted_nodes_ptr] <= root_node;

// end


wire _unused_ok = 1'b0 && &{1'b0,
    empty_nodes_fifo[wr_ptr],
    rd_ptr,
    src_node,
    dst_node,
    src_node_valid,
    edge_valid,
    1'b0};

endmodule
`default_nettype wire
