`timescale 1ns/1ps
`default_nettype none

module range_check #(
    parameter int RANGE_WIDTH
)(
    input wire clk,
    // Upstream Range Check Unit
        input wire upstream_conf_done,
        input wire upstream_valid,
        input wire [RANGE_WIDTH-1:0] upstream_data,
    // Downstream Range Check Unit
        output logic downstream_conf_done,
        output logic downstream_valid,
        output logic [RANGE_WIDTH-1:0] downstream_data
);

typedef logic [RANGE_WIDTH-1:0] data_t;

logic max_below_set = 1'b0, min_above_set = 1'b0;
data_t max_below = '1, min_above = '0;

initial max_below = '1;
initial min_above = '0;

always_ff @(posedge clk) begin: capture_max_below
    if (upstream_valid && !upstream_conf_done && !max_below_set) begin
        max_below_set <= 1'b1;
        max_below <= upstream_data;
    end
end

always_ff @(posedge clk) begin: capture_min_above
    if (!upstream_conf_done && upstream_valid && max_below_set && !min_above_set) begin
        min_above_set <= 1'b1;
        min_above <= upstream_data;
    end
end

always_ff @(posedge clk) begin: forward_conf_done
    downstream_conf_done <= upstream_conf_done;
end

always_ff @(posedge clk) begin: forward_data
    downstream_valid <= 1'b0;
    if (max_below_set && min_above_set) begin: forward_conf_data
        downstream_valid <= upstream_valid;
        downstream_data <= upstream_data;
    end else if (upstream_conf_done) begin: tail_units_without_conf_data
        downstream_valid <= upstream_valid;
        downstream_data <= upstream_data;
    end else begin
        downstream_valid <= 1'b0;
        downstream_data <= '0;
    end
end

wire _unused_ok = 1'b0 && &{1'b0,
    max_below, min_above,
    1'b0};

endmodule
`default_nettype wire
