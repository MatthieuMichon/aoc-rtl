`timescale 1ns/1ps
`default_nettype none

module range_check #(
    parameter int ID_WIDTH
)(
    input wire clk,
    // Upstream Range Check Unit
        input wire upstream_dump_done,
        input wire upstream_conf_done,
        input wire upstream_valid,
        input wire [ID_WIDTH-1:0] upstream_lower_id,
        input wire [ID_WIDTH-1:0] upstream_upper_id,
    // Downstream Range Check Unit
        output logic downstream_dump_done,
        output logic downstream_conf_done,
        output logic downstream_valid,
        output logic [ID_WIDTH-1:0] downstream_lower_id,
        output logic [ID_WIDTH-1:0] downstream_upper_id
);

typedef logic [ID_WIDTH-1:0] id_t;

logic range_set = 1'b0, range_dumped = 1'b0;
logic range_overlap;
id_t lower_id = '1, upper_id = '0;

assign range_overlap = (lower_id <= upstream_upper_id) && (upper_id >= upstream_lower_id);

always_ff @(posedge clk) begin: range_capture
    if (upstream_valid) begin
        if (!range_set) begin: initial_range_set
            range_set <= !upstream_conf_done;
            lower_id <= upstream_lower_id;
            upper_id <= upstream_upper_id;
        end else begin
            if (range_overlap) begin: overlap
                lower_id <= (upstream_lower_id < lower_id) ? upstream_lower_id : lower_id;
                upper_id <= (upper_id < upstream_upper_id) ? upstream_upper_id : upper_id;
            end
        end
    end
end

initial begin: range_init
    downstream_dump_done = 1'b0;
    downstream_conf_done = 1'b0;
    downstream_valid = 1'b0;
    downstream_lower_id = '1;
    downstream_upper_id = '0;
end

always_ff @(posedge clk) begin: range_forward
    downstream_valid <= 1'b0;
    if (!upstream_conf_done) begin: configuration_phase
        if (range_set && upstream_valid) begin
            if (!range_overlap) begin: cfg_no_overlap
                downstream_valid <= 1'b1;
                downstream_lower_id <= upstream_lower_id;
                downstream_upper_id <= upstream_upper_id;
            end
        end
    end else if (!upstream_dump_done) begin: dump_phase
        if (upstream_valid) begin
            if (!range_set || !range_overlap) begin: dump_unset_or_no_overlap
                downstream_valid <= 1'b1;
                downstream_lower_id <= upstream_lower_id;
                downstream_upper_id <= upstream_upper_id;
            end
        end
    end else if (!range_dumped) begin: dump_done
        range_dumped <= 1'b1;
        if (range_set) begin: dump_local_range
            downstream_valid <= 1'b1;
            downstream_lower_id <= lower_id;
            downstream_upper_id <= upper_id;
        end
    end else begin
        downstream_dump_done <= 1'b1;
    end
end

always_ff @(posedge clk) downstream_conf_done <= upstream_conf_done;

wire _unused_ok = 1'b0 && &{1'b0,
    range_dumped,
    1'b0};

endmodule
`default_nettype wire
