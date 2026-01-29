`timescale 1ns/1ps
`default_nettype none

module hash_filter #(
    parameter int DIGEST_WIDTH = 128, // bits
    parameter int LEADING_ZEROES = 5
) (
    input wire clk,
    input wire reset,
    // Digest Input
        input wire digest_valid,
        input wire [DIGEST_WIDTH-1:0] digest_data,
    // Filtered Output
        output logic filtered_valid,
        output logic [DIGEST_WIDTH-1:0] filtered_data
);

typedef logic [DIGEST_WIDTH-1:0] digest_t;
localparam digest_t MASK = {
    {4*LEADING_ZEROES{1'b1}}, {DIGEST_WIDTH-4*LEADING_ZEROES{1'b0}}};

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        filtered_valid <= 1'b0;
    end else begin
        if (digest_valid && !(digest_data & MASK)) begin
            filtered_valid <= 1'b1;
            filtered_data <= digest_data;
        end else begin
            filtered_valid <= 1'b0;
        end
    end
end

endmodule
`default_nettype wire
