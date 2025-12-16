`timescale 1ns/1ps
`default_nettype none

module node_id_mapper #(
    parameter int NODE_STR_WIDTH = 15, // do not override
    parameter int MAX_NODES = 1024,
    parameter int NODE_IDX_WIDTH = $clog2(MAX_NODES)
)(
    input wire clk,
    // Node with Random Identifier
        input wire decoding_done_str,
        input wire edge_str_valid,
        input wire src_node_str_valid, // for early src_node LUT registration
        input wire [NODE_STR_WIDTH-1:0] src_node_str,
        input wire [NODE_STR_WIDTH-1:0] dst_node_str,
    // Node with Indexed Identifier
        output logic decoding_done_idx,
        output logic edge_idx_valid,
        output logic src_node_idx_valid,
        output logic [NODE_IDX_WIDTH-1:0] src_node_idx,
        output logic [NODE_IDX_WIDTH-1:0] dst_node_idx,
        output logic [NODE_IDX_WIDTH-1:0] node_idx_cnt = '0,
    // Static Start and End Nodes
        output logic [NODE_IDX_WIDTH-1:0] start_node_idx,
        output logic [NODE_IDX_WIDTH-1:0] end_node_idx,
        output logic start_end_nodes_valid
);

localparam byte A_CHAR = 8'h61;
localparam logic ASSIGNED = 1'b1;
typedef logic [NODE_STR_WIDTH-1:0] node_str_t;
typedef logic [NODE_IDX_WIDTH-1:0] node_idx_t;

function node_str_t node_str_from_node_ascii(string node_ascii);
    node_str_from_node_ascii[15-1-:5] = 5'(node_ascii[2] - A_CHAR);
    node_str_from_node_ascii[10-1-:5] = 5'(node_ascii[1] - A_CHAR);
    node_str_from_node_ascii[5-1-:5] = 5'(node_ascii[0] - A_CHAR);
endfunction

localparam string START_NODE = "you";
localparam string END_NODE = "out";
localparam node_str_t start_node_str = node_str_from_node_ascii(START_NODE);
localparam node_str_t end_node_str = node_str_from_node_ascii(END_NODE);

typedef struct packed {
    logic index_assigned;
    node_idx_t node_index;
} node_index_entry_t;

node_index_entry_t node_lut[2**NODE_STR_WIDTH-1:0] =
    '{default: '{index_assigned: 1'b0, node_index: NODE_IDX_WIDTH'(0)}};

always_ff @(posedge clk) decoding_done_idx <= decoding_done_str;

always_ff @(posedge clk) begin: src_node_id_tracking
    if (src_node_str_valid && !node_lut[src_node_str].index_assigned) begin
        node_lut[src_node_str] <= {ASSIGNED, node_idx_cnt};
    end
end

always_ff @(posedge clk) begin: dst_node_id_tracking
    if (edge_str_valid && !node_lut[dst_node_str].index_assigned) begin
        node_lut[dst_node_str] <= {ASSIGNED, node_idx_cnt};
    end
end

// IMPORTANT: Assumes `src_node_str_valid` and `edge_str_valid` not both asserted at the same time
always_ff @(posedge clk) begin: node_idx_cnt_increment
    if (src_node_str_valid && !node_lut[src_node_str].index_assigned) begin
        node_idx_cnt <= node_idx_cnt + 1;
    end else if (edge_str_valid && !node_lut[dst_node_str].index_assigned) begin
        node_idx_cnt <= node_idx_cnt + 1;
    end
end

always_ff @(posedge clk) begin: src_node_lookup
    if (src_node_str_valid) begin
        src_node_idx_valid <= 1'b1;
        if (!node_lut[src_node_str].index_assigned) begin
            src_node_idx <= node_idx_cnt;
        end else begin
            src_node_idx <= node_lut[src_node_str].node_index;
        end
    end else begin
        src_node_idx_valid <= 1'b0;
    end
end

always_ff @(posedge clk) begin: dst_node_lookup
    if (edge_str_valid) begin
        edge_idx_valid <= 1'b1;
        if (!node_lut[dst_node_str].index_assigned) begin
            dst_node_idx <= node_idx_cnt;
        end else begin
            dst_node_idx <= node_lut[dst_node_str].node_index;
        end
    end else begin
        edge_idx_valid <= 1'b0;
    end
end

logic prev_src_node_was_start, prev_dst_node_was_end;
logic start_node_captured, end_node_captured;

always_ff @(posedge clk) begin: start_end_nodes
    if (prev_src_node_was_start) begin
        start_node_idx <= src_node_idx;
        start_node_captured <= 1'b1;
    end
    if (prev_dst_node_was_end) begin
        end_node_idx <= dst_node_idx;
        end_node_captured <= 1'b1;
    end
    prev_src_node_was_start <= src_node_str_valid && (src_node_str == start_node_str);
    prev_dst_node_was_end <= edge_str_valid && (dst_node_str == end_node_str);
    start_end_nodes_valid <= start_node_captured && end_node_captured;
end

endmodule
`default_nettype wire
