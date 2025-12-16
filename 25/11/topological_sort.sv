`timescale 1ns/1ps
`default_nettype none

module topological_sort #(
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
    // Indegree List Interface
        output logic [NODE_WIDTH-1:0] indeg_node,
        output logic indeg_dec,
        input wire [NODE_WIDTH-1:0] indeg_degree,
    // Adjacency Map Query/Reply Interface
        input wire query_ready,
        output logic query_valid,
        output logic [NODE_WIDTH-1:0] query_data,
        input wire reply_last,
        output logic reply_ready,
        input wire reply_valid,
        input wire [NODE_WIDTH-1:0] reply_data,
        input wire reply_no_edges_found,
    // Sorted Nodes
        output logic sorted_done,
        output logic sorted_valid,
        output logic [NODE_WIDTH-1:0] sorted_node
);

localparam int EDGE_ADDR_WIDTH = $clog2(MAX_EDGES);
typedef logic [NODE_WIDTH-1:0] node_t;
typedef logic [EDGE_ADDR_WIDTH-1:0] edge_addr_t;

node_t zero_indeg_nodes_fifo[MAX_NODES-1:0];
node_t dst_node_cnt = '0, queue_wr_ptr = '0, queue_rd_ptr = '0, queue_wr_data = '0, root_node = '0;
logic sweep_pending;

typedef enum {
    INITIAL_SWEEP,
    KAHNS_ALGORITHM
} queue_wr_sel_t;
queue_wr_sel_t queue_wr_sel;

typedef enum logic [3:0] {
    WAIT_DECODING_DONE,
    RUN_INITIAL_SWEEP,
    START_INITIAL_SWEEP,
    LOAD_NEXT_ROOT_NODE,
    ISSUE_ADJ_NODES_SCAN_QUERY,
    WAIT_ADJ_NODES_SCAN_QUERY,
    ISSUE_ADJ_NODE_DEGREE,
    CHECK_ADJ_NODE_DEGREE,
    DONE
} state_t;
state_t current_state, next_state;

logic queue_wr_en, queue_rd_en, alg_queue_we;

always_ff @(posedge clk) current_state <= next_state;

always_comb begin: state_logic
    unique case (current_state)
        WAIT_DECODING_DONE: begin
            if (!decoding_done) begin: input_decoding_pending
                next_state = WAIT_DECODING_DONE;
            end else begin
                next_state = START_INITIAL_SWEEP;
            end
        end
        START_INITIAL_SWEEP: begin
            next_state = RUN_INITIAL_SWEEP;
        end
        RUN_INITIAL_SWEEP: begin
            if (indeg_node < node_idx_cnt) begin
                next_state = RUN_INITIAL_SWEEP;
            end else begin
                next_state = LOAD_NEXT_ROOT_NODE;
            end
        end
        LOAD_NEXT_ROOT_NODE: begin
            next_state = ISSUE_ADJ_NODES_SCAN_QUERY;
        end
        ISSUE_ADJ_NODES_SCAN_QUERY: begin
            if (!query_ready || !query_valid) begin
                next_state = ISSUE_ADJ_NODES_SCAN_QUERY;
            end else begin
                next_state = WAIT_ADJ_NODES_SCAN_QUERY;
            end
        end
        WAIT_ADJ_NODES_SCAN_QUERY: begin
            if (!reply_valid) begin
                next_state = WAIT_ADJ_NODES_SCAN_QUERY;
            end else begin
                if (!reply_no_edges_found) begin: node_has_edges
                    next_state = ISSUE_ADJ_NODE_DEGREE;
                end else begin
                    next_state = DONE;
                end
            end
        end
        ISSUE_ADJ_NODE_DEGREE: begin
            next_state = CHECK_ADJ_NODE_DEGREE;
        end
        CHECK_ADJ_NODE_DEGREE: begin
            if (!reply_last) begin
                next_state = WAIT_ADJ_NODES_SCAN_QUERY;
            end else begin
                next_state = LOAD_NEXT_ROOT_NODE;
            end
        end
        DONE:
            next_state = DONE;
        default:
            next_state = DONE;
    endcase
end

always_comb begin: output_update
    indeg_dec = 1'b0;
    query_valid = 1'b0;
    reply_ready = 1'b0;
    sorted_done = 1'b0;
    sweep_pending = 1'b0;
    queue_wr_sel = INITIAL_SWEEP;
    queue_wr_en = 1'b0;
    queue_rd_en = 1'b0;
    unique case (current_state)
        WAIT_DECODING_DONE: begin
        end
        START_INITIAL_SWEEP: begin
            sweep_pending = 1'b1;
        end
        RUN_INITIAL_SWEEP: begin
            sweep_pending = 1'b1;
            queue_wr_sel = INITIAL_SWEEP;
            queue_wr_en = (indeg_degree == '0);
        end
        LOAD_NEXT_ROOT_NODE: begin
            queue_wr_sel = KAHNS_ALGORITHM;
            queue_wr_en = 1'b0;
            queue_rd_en = 1'b1;
        end
        ISSUE_ADJ_NODES_SCAN_QUERY: begin
            query_valid = 1'b1;
            queue_wr_sel = KAHNS_ALGORITHM;
            queue_wr_en = alg_queue_we;
            queue_rd_en = 1'b0;
        end
        WAIT_ADJ_NODES_SCAN_QUERY: begin
            queue_wr_sel = KAHNS_ALGORITHM;
        end
        ISSUE_ADJ_NODE_DEGREE: begin
            indeg_dec = 1'b1;
            reply_ready = 1'b1;
            queue_wr_sel = KAHNS_ALGORITHM;
        end
        CHECK_ADJ_NODE_DEGREE: begin
            queue_wr_sel = KAHNS_ALGORITHM;
            queue_wr_en = (indeg_degree == '0);
        end
        DONE: begin
            reply_ready = 1'b0;
            sorted_done = reply_no_edges_found;
            sweep_pending = 1'b0;
            queue_wr_sel = KAHNS_ALGORITHM;
            queue_wr_en = 1'b0;
            queue_rd_en = 1'b0;
        end
        default: begin
        end
    endcase
end

node_t prev_indeg_node, alg_queue_wr_data;

always_ff @(posedge clk) begin: adjacency_map_query
    if (sweep_pending) begin: initial_sweep
        prev_indeg_node <= indeg_node;
        indeg_node <= indeg_node + 1;
    end else if (queue_wr_sel == KAHNS_ALGORITHM) begin: sort_algorithm
        indeg_node <= reply_data;
    end
end

assign alg_queue_wr_data = indeg_node;
assign queue_wr_data = (queue_wr_sel == INITIAL_SWEEP) ? prev_indeg_node : alg_queue_wr_data;

always_ff @(posedge clk) begin: queue_wr
    if (queue_wr_en) begin: write_enable
        zero_indeg_nodes_fifo[queue_wr_ptr] <= queue_wr_data;
        queue_wr_ptr <= queue_wr_ptr + 1;
    end
end

always_ff @(posedge clk) begin: queue_rd
    sorted_valid <= 1'b0;
    if (queue_rd_en) begin: read_enable
        root_node <= zero_indeg_nodes_fifo[queue_rd_ptr];
        queue_rd_ptr <= queue_rd_ptr + 1;
        sorted_valid <= 1'b1;
    end
end

assign query_data = root_node;
assign sorted_node  = root_node;

wire _unused_ok = 1'b0 && &{1'b0,
    zero_indeg_nodes_fifo[queue_wr_ptr],
    src_node,
    dst_node,
    src_node_valid,
    edge_valid,
    1'b0};

endmodule
`default_nettype wire
