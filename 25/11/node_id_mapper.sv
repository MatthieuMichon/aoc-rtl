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
        input wire src_node_str_valid, // for early src_node LUT registration
        input wire edge_str_valid,
        input wire [NODE_STR_WIDTH-1:0] src_node_str,
        input wire [NODE_STR_WIDTH-1:0] dst_node_str,
    // Node with Indexed Identifier
        output logic decoding_done_idx,
        output logic src_node_idx_valid,
        output logic edge_idx_valid,
        output logic [NODE_IDX_WIDTH-1:0] src_node_idx,
        output logic [NODE_IDX_WIDTH-1:0] dst_node_idx,
        output logic [NODE_IDX_WIDTH-1:0] node_idx_cnt,
    // Static Start and End Nodes
        output logic [NODE_IDX_WIDTH-1:0] start_node_idx,
        output logic [NODE_IDX_WIDTH-1:0] end_node_idx,
        output logic start_end_nodes_valid
);

localparam string START_NODE = "you";
localparam string END_NODE = "out";
typedef enum logic {
    UNASSIGNED = 1'b0,
    ASSIGNED = 1'b1
} node_index_state_t;
localparam byte unsigned A_CHAR = 8'h61;
typedef logic [NODE_STR_WIDTH-1:0] node_str_t;
typedef logic [NODE_IDX_WIDTH-1:0] node_idx_t;
function node_str_t node_str_from_node_ascii(string node_ascii);
    node_str_from_node_ascii[15-1-:5] = 5'(node_ascii[2] - A_CHAR);
    node_str_from_node_ascii[10-1-:5] = 5'(node_ascii[1] - A_CHAR);
    node_str_from_node_ascii[5-1-:5] = 5'(node_ascii[0] - A_CHAR);
endfunction
node_str_t start_node_str = node_str_from_node_ascii(START_NODE);
node_str_t end_node_str = node_str_from_node_ascii(END_NODE);
typedef struct packed {
    logic index_state;
    node_idx_t node_index;
} node_index_entry_t;
typedef logic [$size(node_index_entry_t)-1:0] flat_entry_t;
//flat_entry_t node_lut[2**NODE_STR_WIDTH-1:0];

logic prev_src_node_str_valid = 1'b0, prev_dst_node_str_valid = 1'b0;
node_str_t prev_src_node_str, prev_dst_node_str;
logic node_lut_src_wr_en, node_lut_dst_wr_en;
node_index_entry_t node_lut_src_rd_data, node_lut_src_wr_data;
node_index_entry_t node_lut_dst_rd_data, node_lut_dst_wr_data;
node_idx_t current_index = '0;
logic start_node_captured = 1'b0, end_node_captured = 1'b0;

always_ff @(posedge clk) prev_src_node_str_valid <= src_node_str_valid;
always_ff @(posedge clk) prev_dst_node_str_valid <= edge_str_valid;
always_ff @(posedge clk) prev_src_node_str <= src_node_str;
always_ff @(posedge clk) prev_dst_node_str <= dst_node_str;
always_ff @(posedge clk) src_node_idx_valid <= prev_src_node_str_valid;
always_ff @(posedge clk) edge_idx_valid <= prev_dst_node_str_valid;

// always_ff @(posedge clk) begin: src_node_port
//     if (node_lut_src_wr_en) begin
//         node_lut[src_node_str] <= node_lut_src_wr_data;
//     end
//     node_lut_src_rd_data <= node_lut[src_node_str];
// end

// always_ff @(posedge clk) begin: dst_node_port
//     if (node_lut_dst_wr_en) begin
//         node_lut[dst_node_str] <= node_lut_dst_wr_data;
//     end
//     node_lut_dst_rd_data <= node_lut[dst_node_str];
// end

node_id_mapper_dpram #(
    .NODE_STR_WIDTH(NODE_STR_WIDTH),
    .MAX_NODES(MAX_NODES),
    .NODE_IDX_WIDTH(NODE_IDX_WIDTH)
) node_id_mapper_dpram_i (
    .clk(clk),
    .node_lut_src_wr_en(node_lut_src_wr_en),
    .node_lut_dst_wr_en(node_lut_dst_wr_en),
    .src_node_str(src_node_str),
    .dst_node_str(dst_node_str),
    .node_lut_src_wr_data(node_lut_src_wr_data),
    .node_lut_dst_wr_data(node_lut_dst_wr_data),
    .node_lut_src_rd_data(node_lut_src_rd_data),
    .node_lut_dst_rd_data(node_lut_dst_rd_data)
);

check_valid_exclusivity: assert property (
    @(posedge clk) !(prev_src_node_str_valid && prev_dst_node_str_valid)
) else $error("Simultaneous source and destination node string mapping requests");

always_ff @(posedge clk) begin: internal_state_tracking
    src_node_idx <= node_lut_src_rd_data.node_index;
    node_lut_src_wr_en <= 1'b0;
    dst_node_idx <= node_lut_dst_rd_data.node_index;
    node_lut_dst_wr_en <= 1'b0;
    if (prev_src_node_str_valid && (node_lut_src_rd_data.index_state == 1'b0)) begin
        src_node_idx <= current_index;
        node_lut_src_wr_en <= 1'b1;
        node_lut_src_wr_data <= {1'b1, current_index};
        current_index <= current_index + 1'b1;
    end else if (prev_dst_node_str_valid && (node_lut_dst_rd_data.index_state == 1'b0)) begin
        dst_node_idx <= current_index;
        node_lut_dst_wr_en <= 1'b1;
        node_lut_dst_wr_data <= {1'b1, current_index};
        current_index <= current_index + 1'b1;
    end
end

assign node_idx_cnt = current_index;

logic start_node_found;

always_ff @(posedge clk) begin: start_end_nodes
    start_node_found <= 1'b0;
    if (src_node_idx_valid && (src_node_str == start_node_str)) begin
        start_node_idx <= src_node_idx;
        start_node_captured <= 1'b1;
        start_node_found <= 1'b1;
    end
    if (prev_dst_node_str_valid && (prev_dst_node_str == end_node_str)) begin
        end_node_idx <= dst_node_idx;
        end_node_captured <= 1'b1;
    end
    start_end_nodes_valid <= start_node_captured && end_node_captured;
end

initial begin
    decoding_done_idx = 1'b0;
    src_node_idx_valid = 1'b0;
    edge_idx_valid = 1'b0;
    start_end_nodes_valid = 1'b0;
end

always_ff @(posedge clk) decoding_done_idx <= decoding_done_str;

wire _unused_ok = 1'b0 && &{1'b0,
    prev_src_node_str,  // To be fixed
    start_node_found,
    1'b0};

endmodule
`default_nettype wire
