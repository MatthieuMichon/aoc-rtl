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

typedef struct packed {
    logic assigned;
    node_cnt_t id;
} node_id_lut_entry_t;

node_id_lut_entry_t node_id_lut[2**NODE_WIDTH-1:0];
node_cnt_t in_degree_per_node[2**NODE_CNT_WITDH-1:0];
node_cnt_t out_degree_per_node[2**NODE_CNT_WITDH-1:0];
edge_ptr_t next_node_ptr_per_node[2**NODE_CNT_WITDH-1:0];
node_t next_node[MAX_EDGE_QTY-1:0];

localparam byte A_CHAR = 8'h61; // lowercase: `a`
function node_t node_from_ascii(string char);
    node_from_ascii[15-1-:5] = 5'(char[2] - A_CHAR);
    node_from_ascii[10-1-:5] = 5'(char[1] - A_CHAR);
    node_from_ascii[5-1-:5] = 5'(char[0] - A_CHAR);
endfunction;
function string node_to_ascii(node_t node);
    node_to_ascii = "   ";
    node_to_ascii[2] = 8'(node[15-1-:5] + A_CHAR);
    node_to_ascii[1] = 8'(node[10-1-:5] + A_CHAR);
    node_to_ascii[0] = 8'(node[5-1-:5] + A_CHAR);
endfunction;

node_cnt_t node_id_index = '0;

always_ff @(posedge clk) begin: node_id_tracking
    if (edge_valid) begin
        node_id_index <= node_id_index +
            (!node_id_lut[src_node].assigned ? 1 : 0) +
            (!node_id_lut[dst_node].assigned ? 1 : 0);
    end
end

always_ff @(posedge clk) begin: src_node_id_tracking
    if (edge_valid && !node_id_lut[src_node].assigned) begin
        node_id_lut[src_node].assigned <= 1'b1;
        node_id_lut[src_node].id <= node_id_index;
        //$display("node_id_lut[0x%04x(%d-%s)] index %d from src_node", src_node, src_node, node_to_ascii(src_node), node_id_index);
    end
end

always_ff @(posedge clk) begin: dst_node_id_tracking
    if (edge_valid && !node_id_lut[dst_node].assigned) begin
        node_id_lut[dst_node].assigned <= 1'b1;
        node_id_lut[dst_node].id <= node_id_index + (!node_id_lut[src_node].assigned ? 1 : 0);
        //$display("node_id_lut[0x%04x(%d-%s)] index %d from dst_node", dst_node, dst_node, node_to_ascii(dst_node), $bits(node_id_index)'(node_id_index + (!node_id_lut[src_node].assigned ? 1 : 0)));
    end
end

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

localparam node_t start_node = node_from_ascii("you");


always_ff @(posedge clk) begin
    if (!path_count_init_done) begin
        path_count_per_node[start_node] <= 1;
    end
end

initial begin
    @(posedge edge_last);
    $display("node_id_index: %d", node_id_index);
    for (node_cnt_t i = 0; i < node_id_index; i++) begin
        $display("node_id %d: assigned %d -> node 0x%03x-%s", i, node_id_lut[i].assigned, node_id_lut[i].id, node_to_ascii(node_id_lut[i].id));
        @(posedge clk);
    end
    //$display("path_count_per_node: %p", path_count_per_node);
    for (edge_ptr_t i = 0; i < MAX_NODE_QTY; i++) begin
        //$display("%d -> %d", next_node[i], next_node[next_node_ptr_per_node[next_node[i]]]);
    end
end

endmodule
`default_nettype wire
