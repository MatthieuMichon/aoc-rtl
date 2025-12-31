`timescale 1ns/1ps
`default_nettype none

module node_list_trim #(
    parameter int MAX_NODES = 1024,
    parameter int NODE_WIDTH = $clog2(MAX_NODES)
)(
    input wire clk,
    // Static Start and End Nodes
        input wire [NODE_WIDTH-1:0] start_node_idx,
        input wire [NODE_WIDTH-1:0] end_node_idx,
        input wire start_end_nodes_valid,
    // Sorted Nodes
        input wire sorted_done,
        input wire sorted_valid,
        input wire [NODE_WIDTH-1:0] sorted_node,
    // Trimed Sorted Nodes
        output logic trimed_done,
        output logic trimed_valid,
        output logic [NODE_WIDTH-1:0] trimed_node
);

logic forward_node_list;

initial begin
    trimed_done = 1'b0;
    trimed_valid = 1'b0;
    forward_node_list = 1'b0;
end

always_ff @(posedge clk) begin
    if (!start_end_nodes_valid) begin: abnormal_discard_prior_valid_config
        forward_node_list <= 1'b0;
        trimed_done <= 1'b0;
        trimed_valid <= 1'b0;
    end else if (sorted_node == start_node_idx) begin: start_node
        forward_node_list <= 1'b1;
        trimed_done <= 1'b0;
        trimed_valid <= sorted_valid;
        trimed_node <= sorted_node;
    end else if (forward_node_list) begin: node_forwarding
        forward_node_list <= (sorted_node != end_node_idx);
        trimed_done <= sorted_done;
        trimed_valid <= sorted_valid;
        trimed_node <= sorted_node;
    end else if (trimed_node == end_node_idx) begin: end_node
        forward_node_list <= 1'b0;
        trimed_done <= 1'b1;
        trimed_valid <= 1'b0;
        trimed_node <= sorted_node;
    end else begin: before_start_or_after_end
        trimed_valid <= 1'b0;
    end
end

endmodule
`default_nettype wire
