`timescale 1ns/1ps
`default_nettype none

module user_logic (
    input wire tck,
    input wire tdi,
    output logic tdo,
    input wire test_logic_reset,
    input wire run_test_idle,
    input wire ir_is_user,
    input wire capture_dr,
    input wire shift_dr,
    input wire update_dr
);

localparam int BYTE_WIDTH = $bits(byte);
// From design space exploration
localparam int RESULT_WIDTH = 16;
parameter int DEVICE_CHARS = 3;
parameter int DEVICE_BIN_BITS = 5;
parameter int DEVICE_WIDTH = DEVICE_CHARS*DEVICE_BIN_BITS;
parameter int MAX_NODES = 1024;
parameter int NODE_WIDTH = $clog2(MAX_NODES);

typedef logic [NODE_WIDTH-1:0] node_t;

logic inbound_valid;
logic [BYTE_WIDTH-1:0] inbound_data;

tap_decoder #(.DATA_WIDTH(BYTE_WIDTH)) tap_decoder_i (
    // TAP signals
        .tck(tck),
        .tdi(tdi),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .shift_dr(shift_dr),
        .update_dr(update_dr),
    // Decoded signals
        .valid(inbound_valid),
        .data(inbound_data)
);

logic decoding_done_str;
logic edge_str_valid;
logic src_node_str_valid;
logic [DEVICE_WIDTH-1:0] src_node_str;
logic [DEVICE_WIDTH-1:0] dst_node_str;

input_decoder input_decoder_i (
    .clk(tck),
    // Inbound Byte Stream
        .byte_valid(inbound_valid),
        .byte_data(inbound_data),
    // Decoded signals
        .decoding_done(decoding_done_str),
        .edge_valid(edge_str_valid),
        .src_node_valid(src_node_str_valid),
        .src_node(src_node_str),
        .dst_node(dst_node_str)
);

logic decoding_done_idx;
logic edge_idx_valid;
logic src_node_idx_valid;
node_t src_node_idx;
node_t dst_node_idx;
node_t node_idx_cnt;

node_id_mapper node_id_mapper_i (
    .clk(tck),
    // Node with Random Identifier
        .decoding_done_str(decoding_done_str),
        .edge_str_valid(edge_str_valid),
        .src_node_str_valid(src_node_str_valid),
        .src_node_str(src_node_str),
        .dst_node_str(dst_node_str),
    // Node with Indexed Identifier
        .decoding_done_idx(decoding_done_idx),
        .edge_idx_valid(edge_idx_valid),
        .src_node_idx_valid(src_node_idx_valid),
        .src_node_idx(src_node_idx),
        .dst_node_idx(dst_node_idx),
        .node_idx_cnt(node_idx_cnt)
);

logic query_ready;
logic query_valid;
node_t query_data;
logic reply_ready;
logic reply_valid;
logic reply_last;
node_t reply_data;

adjacency_map adjacency_map_i(
    .clk(tck),
    // Connection Entries
        .decoding_done(decoding_done_idx),
        .edge_valid(edge_idx_valid),
        .src_node_valid(src_node_idx_valid),
        .src_node(src_node_idx),
        .dst_node(dst_node_idx),
        .node_idx_cnt(node_idx_cnt),
    // Query/Reply Interface
        .query_ready(query_ready),
        .query_valid(query_valid),
        .query_data(query_data),
        .reply_ready(reply_ready),
        .reply_valid(reply_valid),
        .reply_last(reply_last),
        .reply_data(reply_data)
);

logic [$clog2(1024)-1:0] indeg_node = '0;
logic indeg_dec = 1'b0;
logic [$clog2(1024)-1:0] indeg_degree;

indegree_list indegree_list_i (
    .clk(tck),
    // Connection Entries
        .edge_valid(edge_idx_valid),
        .dst_node(dst_node_idx),
    // Update Interface
        .node_sel(indeg_node),
        .decrement_degree(indeg_dec),
        .node_degree(indeg_degree) // degree after decrement
);

logic sorted_last;
logic sorted_valid;
node_t sorted_node;

topological_sort topological_sort_i (
    .clk(tck),
    // Connection Entries
        .decoding_done(decoding_done_idx),
        .edge_valid(edge_idx_valid),
        .src_node_valid(src_node_idx_valid),
        .src_node(src_node_idx),
        .dst_node(dst_node_idx),
        .node_idx_cnt(node_idx_cnt),
    // Indegree List Interface
        .indeg_node(indeg_node),
        .indeg_dec(indeg_dec),
        .indeg_degree(indeg_degree), // degree after decrement
    // Query/Reply Interface
        .query_ready(query_ready),
        .query_valid(query_valid),
        .query_data(query_data),
        .reply_ready(reply_ready),
        .reply_valid(reply_valid),
        .reply_last(reply_last),
        .reply_data(reply_data),
    // Sorted Nodes
        .sorted_last(sorted_last),
        .sorted_valid(sorted_valid),
        .sorted_node(sorted_node)
);

// forward_pass_processor forward_pass_processor_i (
//     .clk(tck),
//     // Connection entries
//         .end_of_file(end_of_file),
//         .connection_valid(connection_valid),
//         .connection_last(connection_last), // for a given device
//         .device(device),
//         .next_device(next_device)
// );

logic outbound_valid = 1'b0;
logic [RESULT_WIDTH-1:0] outbound_data = '0;

tap_encoder #(.DATA_WIDTH(RESULT_WIDTH)) tap_encoder_i (
    // TAP signals
        .tck(tck),
        .tdo(tdo),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
    // Encoded signals
        .valid(outbound_valid),
        .data(outbound_data)
);

wire _unused_ok = 1'b0 && &{1'b0,
    indeg_degree,
    sorted_last,
    sorted_valid,
    sorted_node,
    run_test_idle,  // To be fixed
    1'b0};

endmodule
`default_nettype wire
