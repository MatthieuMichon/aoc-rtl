`timescale 1ns/1ps
`default_nettype none

module dial_tracker #(
    parameter int CLICK_BITS,
    parameter int DIAL_CLICKS
)(
    input wire clk,
    // Decoded Line Contents
        input wire click_valid,
        input wire click_right_left,
        input wire [CLICK_BITS-1:0] click_count,
    // Computed Values
        output reg [CLICK_BITS-1:0] zero_crossings
);

typedef logic [CLICK_BITS-1:0] click_cnt_t;
click_cnt_t dial;

initial begin
    dial = 50;
end

always @(posedge clk) begin: clockwise
    if (click_valid && click_right_left) begin
        zero_crossings <= zero_crossings + click_right_left;
    end
end

endmodule
`default_nettype wire
