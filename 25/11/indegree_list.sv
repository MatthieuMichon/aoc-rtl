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
typedef logic [NODE_WIDTH-1:0] indegree_cnt_t;

node_t dst_node_r;
indegree_cnt_t dst_node_hold; // RAMB inference requires unique addr per port
node_t node_sel_r;
indegree_cnt_t node_sel_hold;
indegree_cnt_t indegree_cnt_per_node [2**NODE_WIDTH-1:0];
indegree_cnt_t prev_dst_node_indegree, incr_dst_node_indegree;
indegree_cnt_t prev_node_degree, output_node_degree;
logic prev_edge_valid, prev_decrement_degree;

always @(posedge clk) begin: hold_dst_node
    if (edge_valid) begin
        dst_node_r <= dst_node;
    end
    prev_edge_valid <= edge_valid;
end

assign dst_node_hold = (edge_valid) ? dst_node : dst_node_r;
assign incr_dst_node_indegree = prev_dst_node_indegree + 1;

always @(posedge clk) begin: hold_decr_node
    if (decrement_degree) begin
        node_sel_r <= node_sel;
    end
    prev_decrement_degree <= decrement_degree;
end

assign node_sel_hold = (!prev_decrement_degree) ? node_sel : node_sel_r;

// IMPORTANT: RAMB inference heuristics
// Non-trivial implementations, such as unique different addresses for read and
// write paths or doing even basic arithmetics may cause Vivado build to fail.

always @(posedge clk) begin: read_decr_node_port
    if (prev_decrement_degree) begin
        indegree_cnt_per_node[node_sel_hold] <= output_node_degree;
    end
    prev_node_degree <= indegree_cnt_per_node[node_sel_hold];
end

always @(posedge clk) begin: incr_node_port
    if (prev_edge_valid) begin
        indegree_cnt_per_node[dst_node_hold] <= incr_dst_node_indegree;
    end
    prev_dst_node_indegree <= indegree_cnt_per_node[dst_node_hold];
end

// indegree_list_dpram dpram_i (
//     .clk(clk),
//     .wea(prev_decrement_degree),
//     .web(prev_edge_valid),
//     .addra(node_sel_hold),
//     .addrb(dst_node_hold),
//     .dia(output_node_degree),
//     .dib(incr_dst_node_indegree),
//     .doa(prev_node_degree),
//     .dob(prev_dst_node_indegree)
// );

// End of RAMB inference section

assign output_node_degree = (!prev_decrement_degree) ? prev_node_degree : prev_node_degree - 1;
assign node_degree = output_node_degree;

endmodule
`default_nettype wire
