`timescale 1ns/1ps
`default_nettype none

module indegree_list #(
    parameter int MAX_NODES = 1024,
    parameter int NODE_WIDTH = $clog2(MAX_NODES)
)(
    input wire clk,
    // Edge Entries
        input wire edge_valid,
        input wire [NODE_WIDTH-1:0] dst_node,
    // Update Interface
        input wire [NODE_WIDTH-1:0] node_sel,
        input wire decrement_degree,
        output logic [NODE_WIDTH-1:0] node_degree // degree after decrement
);

typedef logic [NODE_WIDTH-1:0] node_t;

node_t in_degree_table [MAX_NODES-1:0];
node_t incoming_edges;
logic edge_valid_r;
node_t dst_node_r;
node_t stored_node_degree;
node_t node_sel_r;
logic decrement_degree_r;

always_ff @(posedge clk) begin: readback_edge
    if (edge_valid) begin
        incoming_edges <= in_degree_table[dst_node];
    end
end

always_ff @(posedge clk) begin: increment_edge
    if (edge_valid_r) begin
        in_degree_table[dst_node_r] <= incoming_edges + 1;
    end
    edge_valid_r <= edge_valid;
    dst_node_r <= dst_node;
end

always_ff @(posedge clk) stored_node_degree <= in_degree_table[node_sel];

assign node_degree =
    (decrement_degree_r) ? (stored_node_degree - 1) : stored_node_degree;

always_ff @(posedge clk) begin: decrement_edge
    if (decrement_degree_r) begin
        in_degree_table[node_sel_r] <= stored_node_degree - 1;
    end
    decrement_degree_r <= decrement_degree;
    node_sel_r <= node_sel;
end

endmodule
`default_nettype wire
