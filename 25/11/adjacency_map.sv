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
        //input wire [NODE_WIDTH-1:0] node_idx_cnt,
    // Adjacency Query
        output logic query_ready,
        input wire query_valid,
        input wire [NODE_WIDTH-1:0] query_data,
    // Adjacency Reply
        output logic reply_last,
        input wire reply_ready,
        output logic reply_valid,
        output logic [NODE_WIDTH-1:0] reply_data,
        output logic reply_no_edges_found
);

parameter int EDGE_PTR_WIDTH = $clog2(MAX_EDGES);

typedef logic [EDGE_PTR_WIDTH-1:0] edge_list_ptr_t;
typedef struct packed {
    logic node_has_edges;
    edge_list_ptr_t ptr_first;
    edge_list_ptr_t ptr_last;
} node_index_entry_t;
typedef logic [$size(node_index_entry_t)-1:0] flat_entry_t;

typedef logic [NODE_WIDTH-1:0] node_t;
typedef enum logic [1:0] {
    WAIT_DECODING_DONE,
    WAIT_QUERY,
    SET_EDGE_LIST_RD_PTR,
    RETURN_LEAF_NODES
} state_t;
state_t current_state, next_state;

flat_entry_t node_index[MAX_NODES-1:0];
node_t dst_node_list[MAX_EDGES-1:0];
edge_list_ptr_t base_index_ptr = '0, node_index_ptr = '0, dst_node_list_rd_ptr, reply_ptr_last = '0;
logic inc_dst_node_list_rd_ptr;
logic node_has_edges;
logic dst_node_list_ptr_inc;
logic prev_query_enable;
logic prev_dst_node_list_ptr_inc;

always_ff @(posedge clk) begin: write_node_index
    if (src_node_valid) begin: new_src_node
        node_index[src_node] <= {1'b1, node_index_ptr, node_index_ptr};
        base_index_ptr <= node_index_ptr;
    end else if (edge_valid) begin: new_dst_node
        node_index[src_node] <= {1'b1, base_index_ptr, node_index_ptr};
        node_index_ptr <= node_index_ptr + 1;
    end
end

always_ff @(posedge clk) begin: write_dst_node_list
    if (edge_valid) begin
        dst_node_list[node_index_ptr] <= dst_node;
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
            if (!query_valid) begin
                next_state = WAIT_QUERY;
            end else begin
                next_state = SET_EDGE_LIST_RD_PTR;
            end
        end
        SET_EDGE_LIST_RD_PTR: begin
            next_state = RETURN_LEAF_NODES;
        end
        RETURN_LEAF_NODES: begin
            if (!reply_ready || dst_node_list_rd_ptr != reply_ptr_last) begin
                next_state = RETURN_LEAF_NODES;
            end else begin
                next_state = WAIT_QUERY;
            end
        end
    endcase
end

always_comb begin: output_update
    inc_dst_node_list_rd_ptr = 1'b0;
    query_ready = 1'b0;
    unique case (current_state)
        WAIT_DECODING_DONE: begin
        end
        WAIT_QUERY: begin
            query_ready = 1'b1;
        end
        SET_EDGE_LIST_RD_PTR: begin
        end
        RETURN_LEAF_NODES: begin
            inc_dst_node_list_rd_ptr = 1'b1;
        end
    endcase
end

assign dst_node_list_ptr_inc = (reply_ready && reply_valid && !reply_last && inc_dst_node_list_rd_ptr);

always_ff @(posedge clk) begin: update_dst_node_list_rd_ptr
    if (query_valid) begin
        {node_has_edges, dst_node_list_rd_ptr, reply_ptr_last} <= node_index[query_data];
    end else if (dst_node_list_ptr_inc) begin
        dst_node_list_rd_ptr <= dst_node_list_rd_ptr + 1;
    end
end

always_ff @(posedge clk) begin
    reply_data <= dst_node_list[dst_node_list_rd_ptr];
    if (prev_query_enable) begin
        reply_no_edges_found <= !node_has_edges;
    end
    prev_query_enable <= (query_ready && query_valid);
end

//assign reply_valid = new_reply_valid;
always_ff @(posedge clk) begin
    if (!reply_valid) begin
        reply_last <= (prev_query_enable || prev_dst_node_list_ptr_inc) && (dst_node_list_rd_ptr == reply_ptr_last);
        reply_valid <= prev_query_enable || prev_dst_node_list_ptr_inc;
    end else if (reply_ready && reply_valid) begin
        reply_last <= 1'b0;
        reply_valid <= 1'b0;
    end
    prev_dst_node_list_ptr_inc <= dst_node_list_ptr_inc;
end

endmodule
`default_nettype wire
