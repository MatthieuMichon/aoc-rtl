module indegree_list_dpram #(
    parameter int MAX_NODES = 1024,
    parameter int NODE_WIDTH = $clog2(MAX_NODES)
)(
    input wire clk,
    input wire prev_decrement_degree,
    input wire prev_edge_valid,
    input wire [NODE_WIDTH-1:0] node_sel_hold,
    input wire [NODE_WIDTH-1:0] dst_node_hold,
    input wire [NODE_WIDTH-1:0] output_node_degree,
    input wire [NODE_WIDTH-1:0] incr_dst_node_indegree,
    output logic [NODE_WIDTH-1:0] prev_node_degree,
    output logic [NODE_WIDTH-1:0] prev_dst_node_indegree
);

typedef logic [NODE_WIDTH-1:0] indegree_cnt_t;
indegree_cnt_t indegree_cnt_per_node [2**NODE_WIDTH-1:0];

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

endmodule
