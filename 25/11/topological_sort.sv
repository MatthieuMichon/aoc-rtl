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
        input wire [NODE_WIDTH-1:0] dst_node
    // Indegree List Interface
);

localparam int EDGE_ADDR_WIDTH = $clog2(MAX_EDGES);
typedef logic [NODE_WIDTH-1:0] node_t;
typedef logic [EDGE_ADDR_WIDTH-1:0] edge_addr_t;

node_t in_degree_table [MAX_NODES-1:0] = '{default: 0};
node_t incoming_edges;
logic edge_valid_r;
node_t dst_node_r;

always_ff @(posedge clk) begin: readback
    if (edge_valid) begin
        incoming_edges <= in_degree_table[dst_node];
    end
    edge_valid_r <= edge_valid;
    dst_node_r <= dst_node;
end

always_ff @(posedge clk) begin: update
    if (edge_valid_r) begin
        in_degree_table[dst_node_r] <= incoming_edges + 1;
    end
end

node_t empty_nodes_fifo[MAX_NODES-1:0];
node_t wr_ptr = '0, rd_ptr = '0, table_ptr = '0;
logic sweep_pending = 1'b0;

always_ff @(posedge clk) begin: initial_zero_indegree_sweep
    assert(wr_ptr + 1 == rd_ptr) else $error("__LINE__");
    if (decoding_done || sweep_pending) begin
        sweep_pending <= 1'b1;
        if (!|in_degree_table[table_ptr]) begin: root_nodes
            empty_nodes_fifo[wr_ptr] <= table_ptr;
            wr_ptr <= wr_ptr + 1;
            $display("RN[%03x-%d]", table_ptr, table_ptr);
        end
        if (table_ptr == dst_node_r) begin
            sweep_pending <= 1'b0;
        end
        table_ptr <= table_ptr + 1;
    end
end

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
    src_node_valid,
    edge_valid,
    1'b0};

endmodule
`default_nettype wire
