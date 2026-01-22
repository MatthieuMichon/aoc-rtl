`timescale 1ns/1ps
`default_nettype none

module visited_positions #(
    parameter int POSITION_WIDTH
) (
    input wire clk,
    input wire reset,
    // Position Data
        input wire pos_change,
        input wire [POSITION_WIDTH-1:0] pos_x,
        input wire [POSITION_WIDTH-1:0] pos_y,
    // Visited Data
        output logic lookup_valid,
        output logic lookup_already_visited // 1: already visited previously, 0: newly visited
);

localparam int TABLE_ADDR_WIDTH = 2 * POSITION_WIDTH;
typedef logic [TABLE_ADDR_WIDTH-1:0] table_addr_t;

logic ram_rd_valid, ram_rd_data;
table_addr_t visited_table_addr;
logic visited_table [2**TABLE_ADDR_WIDTH-1:0];

initial begin: visited_table_init
    foreach (visited_table[i]) begin
        visited_table[i] = 1'b0;
    end
end

always_ff @(posedge clk) ram_rd_valid <= pos_change && !reset;

assign visited_table_addr = {pos_x, pos_y};
always_ff @(posedge clk) begin: ram
    if (pos_change) begin
        visited_table[visited_table_addr] <= 1'b1;
    end
    ram_rd_data <= visited_table[visited_table_addr];
end

always_ff @(posedge clk) begin
    if (reset) begin
        lookup_valid <= 1'b0;
        lookup_already_visited <= 1'b0;
    end else begin
        lookup_valid <= ram_rd_valid;
        lookup_already_visited <= ram_rd_data;
    end
end

endmodule
`default_nettype wire
