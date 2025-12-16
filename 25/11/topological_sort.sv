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
    // Sorted Nodes
        output logic sorted_last,
        output logic sorted_valid,
        output logic [NODE_WIDTH-1:0] sorted_node
);

localparam int EDGE_ADDR_WIDTH = $clog2(MAX_EDGES);
typedef logic [NODE_WIDTH-1:0] node_t;
typedef logic [EDGE_ADDR_WIDTH-1:0] edge_addr_t;

node_t zero_indeg_nodes_fifo[MAX_NODES-1:0];
node_t dst_node_cnt = '0, queue_wr_ptr = '0, queue_rd_ptr = '0, queue_wr_data = '0;
logic sweep_pending;

typedef enum {
    INITIAL_SWEEP,
    KAHNS_ALGORITHM
} queue_wr_sel_t;
queue_wr_sel_t queue_wr_sel;

typedef enum logic [1:0] {
    WAIT_DECODING_DONE,
    RUN_INITIAL_SWEEP,
    RUN_KAHNS_ALGORITHM,
    DONE
} state_t;
state_t current_state, next_state;

logic queue_wr_en, alg_queue_we;

always_ff @(posedge clk) current_state <= next_state;

always_comb begin: state_logic
    unique case (current_state)
        WAIT_DECODING_DONE: begin
            if (!decoding_done) begin: input_decoding_pending
                next_state = WAIT_DECODING_DONE;
            end else begin
                next_state = RUN_INITIAL_SWEEP;
            end
        end
        RUN_INITIAL_SWEEP: begin
            if (indeg_node < node_idx_cnt) begin
                next_state = RUN_INITIAL_SWEEP;
            end else begin
                next_state = RUN_KAHNS_ALGORITHM;
            end
        end
        RUN_KAHNS_ALGORITHM: begin
            if (queue_wr_ptr != queue_rd_ptr) begin: queue_not_empty
                next_state = RUN_KAHNS_ALGORITHM;
            end else begin
                next_state = DONE;
            end
        end
        DONE:
            next_state = DONE;
    endcase
end

always_comb begin: output_update
    unique case (current_state)
        WAIT_DECODING_DONE: begin
            sweep_pending = 1'b0;
            queue_wr_en = 1'b0;
            queue_wr_sel = INITIAL_SWEEP;
        end
        RUN_INITIAL_SWEEP: begin
            sweep_pending = 1'b1;
            queue_wr_en = (indeg_degree == '0);
            queue_wr_sel = INITIAL_SWEEP;
        end
        RUN_KAHNS_ALGORITHM: begin
            sweep_pending = 1'b0;
            queue_wr_en = alg_queue_we;
            queue_wr_sel = KAHNS_ALGORITHM;
        end
        DONE: begin
            sweep_pending = 1'b0;
            queue_wr_en = 1'b0;
            queue_wr_sel = KAHNS_ALGORITHM;
        end
    endcase
end

node_t prev_indeg_node, alg_queue_wr_data;

always_ff @(posedge clk) begin
    if (sweep_pending) begin
        prev_indeg_node <= indeg_node;
        indeg_node <= indeg_node + 1;
    end
end

assign queue_wr_data = (queue_wr_sel == INITIAL_SWEEP) ? prev_indeg_node : alg_queue_wr_data;

always_ff @(posedge clk) begin: zero_indegree_nodes_queue
    if (queue_wr_en) begin: write_enable
        zero_indeg_nodes_fifo[queue_wr_ptr] <= queue_wr_data;
        queue_wr_ptr <= queue_wr_ptr + 1;
    end
end


assign indeg_dec = 1'b0;






wire _unused_ok = 1'b0 && &{1'b0,
    zero_indeg_nodes_fifo[queue_wr_ptr],
    queue_rd_ptr,
    src_node,
    dst_node,
    src_node_valid,
    edge_valid,
    1'b0};

endmodule
`default_nettype wire
