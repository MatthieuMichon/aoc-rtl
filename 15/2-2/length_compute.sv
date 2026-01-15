`timescale 1ns/1ps
`default_nettype none

module length_compute #(
    parameter int SIZE_WIDTH,
    parameter int LENGTH_WIDTH
)(
    input wire clk,
    // Dimensions
        input wire size_valid,
        input wire [SIZE_WIDTH-1:0] length,
        input wire [SIZE_WIDTH-1:0] width,
        input wire [SIZE_WIDTH-1:0] height,
    // Computed Values
        output logic length_valid,
        output logic [LENGTH_WIDTH-1:0] length_value
);

localparam int PIPELINE_STAGES = 4;

typedef logic [PIPELINE_STAGES-1:0] pipe_t;
typedef logic [SIZE_WIDTH-1:0] size_t;
typedef logic [LENGTH_WIDTH-1:0] length_t;

pipe_t valid_sr;
size_t max_length_or_width, max_stage1_or_height, smallest_perimeter;
length_t volume;

always_ff @(posedge clk) begin: valid_latency
    valid_sr <= {size_valid, valid_sr[$left(valid_sr):1]};
end
assign length_valid = valid_sr[0];

always_ff @(posedge clk) begin: side_lengths
    // first stage
    max_length_or_width <= (length > width) ? length : width;
    // second stage
    max_stage1_or_height <= (max_length_or_width > height) ? max_length_or_width : height;
    // third stage
    smallest_perimeter <= 2 * (length + width + height - max_stage1_or_height);
end

always_ff @(posedge clk) begin: volume_calc
    volume <= LENGTH_WIDTH'(length * width * height);
end

always_ff @(posedge clk) begin: final_length
    length_value <= LENGTH_WIDTH'(smallest_perimeter) + volume;
end

endmodule
`default_nettype wire
