`timescale 1ns/1ps
`default_nettype none

module area_compute #(
    parameter int SIZE_WIDTH,
    parameter int AREA_WIDTH
)(
    input wire clk,
    // Dimensions
        input wire size_valid,
        input wire [SIZE_WIDTH-1:0] length,
        input wire [SIZE_WIDTH-1:0] width,
        input wire [SIZE_WIDTH-1:0] height,
    // Computed Values
        output logic area_valid,
        output logic [AREA_WIDTH-1:0] area_value
);

localparam int PIPELINE_STAGES = 4;

typedef logic [PIPELINE_STAGES-1:0] pipe_t;
typedef logic [SIZE_WIDTH-1:0] size_t;
typedef logic [AREA_WIDTH-1:0] area_t;

pipe_t valid_sr;
area_t side, front, top, six_sides, min_side_or_front, min_stage2_or_top;

always_ff @(posedge clk) begin: valid_latency
    valid_sr <= {size_valid, valid_sr[$left(valid_sr):1]};
end
assign area_valid = valid_sr[0];

always_ff @(posedge clk) begin: side_areas
    // first stage
    side <= (length * width);
    front <= (width * height);
    top <= (height * length);
    // second stage
    six_sides <= (side << 1) + (front << 1) + (top << 1);
end

always_ff @(posedge clk) begin: minimum
    // skip dims reg because valid is sparse and the dims are held
    // second stage
    min_side_or_front <= (length < height) ? side : front;
    // third stage
    min_stage2_or_top <= (min_side_or_front < top) ? min_side_or_front : top;
end

always_ff @(posedge clk) begin: final_area
    area_value <= six_sides + min_stage2_or_top;
end

endmodule
`default_nettype wire
