`timescale 1ns/1ps
`default_nettype none

module node_path_counter #(
    parameter int MAX_NODES = 1024,
    parameter int RESULT_WIDTH = 16,
    parameter int NODE_WIDTH = $clog2(MAX_NODES)
)(
    input wire clk,
    // Trimed Sorted Nodes
        input wire trimed_done,
        input wire trimed_valid,
        input wire [NODE_WIDTH-1:0] trimed_node,
    // Path Count
        output logic path_count_valid,
        output logic [RESULT_WIDTH-1:0] path_count_value
);

always_ff @(posedge clk) begin
    path_count_valid <= 1'b0;
    if (trimed_valid) begin
        path_count_value <= path_count_value + 1'b1;
    end else if (trimed_done) begin
        path_count_valid <= 1'b1;
    end
end

endmodule
`default_nettype wire
