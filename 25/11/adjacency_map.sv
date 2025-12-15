`timescale 1ns/1ps
`default_nettype none

module adjacency_map #(
    parameter int MAX_NODES = 1024,
    parameter int MAX_EDGES = 2048,
    parameter int MAX_EDGE_PER_NODE = 32,
    parameter int NODE_WIDTH = $clog2(MAX_NODES)
)(
    input wire clk,
    // Connection Entries
        input wire decoding_done,
        input wire edge_valid,
        input wire src_node_valid, // for early src_node LUT registration
        input wire [NODE_WIDTH-1:0] src_node,
        input wire [NODE_WIDTH-1:0] dst_node,
        input wire [NODE_WIDTH-1:0] node_idx_cnt
    // Path Count Engine
        // output logic queue_empty,
        // output logic queue_push,
        // input wire [DEVICE_WIDTH-1:0] queue_device,
        // output logic [DEVICE_WIDTH-1:0] queue_count_incr,
        // output logic [8-1:0] queue_count_incr
);

// table: node_index -> pointer to the first entry in node list
// node list: list of nodes

parameter int EDGE_PTR_WIDTH = $clog2(MAX_EDGES);
typedef logic [EDGE_PTR_WIDTH-1:0] edge_list_ptr_t;
typedef struct packed {
    edge_list_ptr_t first_adjacent_edge;
    edge_list_ptr_t last_adjacent_edge;
} node_index_entry_t;




endmodule
`default_nettype wire
