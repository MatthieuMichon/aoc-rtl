`timescale 1ns/1ps
`default_nettype none

module adjacency_map #(
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
    // Query/Reply Interface
        output logic query_ready,
        input wire query_valid,
        input wire [NODE_WIDTH-1:0] query_data,
        input wire reply_ready,
        output logic reply_valid,
        output logic reply_last,
        output logic [NODE_WIDTH-1:0] reply_data
);

// table: node_index -> pointers to the first/last entries in node list
// node list: list of nodes

parameter int EDGE_PTR_WIDTH = $clog2(MAX_EDGES);

typedef logic [EDGE_PTR_WIDTH-1:0] edge_list_ptr_t;
typedef struct packed {
    edge_list_ptr_t ptr_first;
    edge_list_ptr_t ptr_last;
} node_index_entry_t;
typedef logic [NODE_WIDTH-1:0] node_t;
typedef enum logic [1:0] {
    WAIT_DECODING_DONE,
    WAIT_QUERY,
    READ_EDGE_LIST_PTR,
    RETURN_LEAF_NODES
} state_t;
state_t current_state, next_state;

node_index_entry_t node_index[MAX_NODES-1:0];
node_t node_list[MAX_EDGES-1:0];
edge_list_ptr_t node_index_ptr = '0, reply_rd_ptr = '0, reply_ptr_last = '0;

node_t prev_src_node = '1;

always_ff @(posedge clk) begin
    if (edge_valid) begin
        if (prev_src_node != src_node) begin: new_src_node
            node_index[src_node].ptr_first <= node_index_ptr;
            node_index[src_node].ptr_last <= node_index_ptr;
            node_index_ptr <= node_index_ptr + 1;
        end else begin: new_dst_node
            node_index[src_node].ptr_first <= node_index[src_node].ptr_first;
            node_index[src_node].ptr_last <= node_index_ptr;
            node_index_ptr <= node_index_ptr + 1;
        end
        prev_src_node <= src_node;
    end
end

always_ff @(posedge clk) current_state <= next_state;
always_comb begin: state_logic
    unique case (current_state)
        WAIT_DECODING_DONE: begin
            if (!decoding_done) begin: input_decoding_pending
                next_state = WAIT_DECODING_DONE;
            end else begin
                next_state = WAIT_QUERY;
            end
        end
        WAIT_QUERY: begin
            if (!query_ready || !query_valid) begin
                next_state = WAIT_QUERY;
            end else begin
                next_state = READ_EDGE_LIST_PTR;
            end
        end
        READ_EDGE_LIST_PTR: begin
            next_state = RETURN_LEAF_NODES;
        end
        RETURN_LEAF_NODES: begin
            if (!reply_ready || reply_rd_ptr != reply_ptr_last) begin
                next_state = RETURN_LEAF_NODES;
            end else begin
                next_state = WAIT_QUERY;
            end
        end
    endcase
end

always_ff @(posedge clk) begin
    if (query_ready && query_valid) begin
        node_index[query_data].ptr_first <= node_index[query_data].ptr_first;
        node_index[query_data].ptr_last <= node_index[query_data].ptr_last;
    end
end

endmodule
`default_nettype wire
