`timescale 1ns/1ps
`default_nettype none

module topological_sort #(
    parameter int NODE_WIDTH = 15,
    parameter int MAX_NODE_QTY = 1024,
    parameter int MAX_EDGE_QTY = 2048
)(
    input wire clk,
    // Connection Entries
        input wire edge_last, // 1: DAG fully received, 0: edge transfer pending
        input wire edge_valid,
        input wire [NODE_WIDTH-1:0] src_node,
        input wire [NODE_WIDTH-1:0] dst_node
);

localparam int NODE_CNT_WITDH = $clog2(MAX_NODE_QTY);
typedef logic [NODE_CNT_WITDH-1:0] node_cnt_t;
typedef logic [NODE_WIDTH-1:0] node_t;
typedef logic [MAX_EDGE_QTY-1:0] edge_ptr_t;

node_cnt_t in_degree_per_node[2**NODE_CNT_WITDH-1:0];
node_cnt_t out_degree_per_node[2**NODE_CNT_WITDH-1:0];
edge_ptr_t next_node_ptr_per_node[2**NODE_CNT_WITDH-1:0];
node_t next_node[MAX_EDGE_QTY-1:0];

edge_ptr_t path_ptr = '0;

node_t prev_src_node = '1; // invalid node

always_ff @(posedge clk) begin
    if (edge_valid) begin
        in_degree_per_node[dst_node] <= in_degree_per_node[dst_node] + 1;
        out_degree_per_node[src_node] <= out_degree_per_node[src_node] + 1;
        if (src_node != prev_src_node) begin: new_source_node
            next_node_ptr_per_node[src_node] <= path_ptr;
        end
        next_node[path_ptr] <= dst_node;
        prev_src_node <= src_node;
        path_ptr <= path_ptr + 1;
    end
end

typedef logic [16-1:0] path_cnt;
path_cnt path_count_per_node[2**NODE_CNT_WITDH-1:0];
logic path_count_init_done = '0;

localparam byte A_CHAR = 8'h61; // lowercase: `a`
function device_t node_from_ascii(string char);
    node_from_ascii[15-1-:5] = 5'(char[2] - A_CHAR);
    node_from_ascii[10-1-:5] = 5'(char[1] - A_CHAR);
    node_from_ascii[5-1-:5] = 5'(char[0] - A_CHAR);
endfunction
localparam device_t start_node = node_from_ascii("you");

always_ff @(posedge clk) begin
    if (!path_count_init_done) begin
        path_count_per_node[start_node] <= 1;
    end
end

initial begin
    @(posedge edge_last);
    //$display("path_ptr: 0x%04x, next_node: 0x%04x", path_ptr, $size(next_node));
    for (edge_ptr_t i = 0; i < MAX_NODE_QTY; i++) begin
        //$display("%d -> %d", next_node[i], next_node[next_node_ptr_per_node[next_node[i]]]);
    end
end

endmodule
`default_nettype wire
