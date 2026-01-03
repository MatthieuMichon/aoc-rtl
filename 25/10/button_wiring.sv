`timescale 1ns/1ps
`default_nettype none

module button_wiring #(
    parameter int MAX_WIRING_WIDTH
)(
    input wire clk,
    input wire reset, // clear wiring configuration
    // Configuration Daisy Chain
        input wire wiring_valid_in,
        input wire [MAX_WIRING_WIDTH-1:0] wiring_data_in,
        output logic wiring_valid_out,
        output logic [MAX_WIRING_WIDTH-1:0] wiring_data_out,
    // Wiring State
        input wire enable,
        output logic [MAX_WIRING_WIDTH-1:0] wiring
);

typedef logic [MAX_WIRING_WIDTH-1:0] wiring_t;
wiring_t capture_wiring;
logic conf_was_captured = 1'b0;

initial begin
    wiring_valid_out = 1'b0;
    capture_wiring = '0;
end

always_ff @(posedge clk) begin
    if (reset) begin
        wiring_valid_out <= 1'b0;
        conf_was_captured <= 1'b0;
    end else if (wiring_valid_in) begin
        if (!conf_was_captured) begin: capture_conf
            conf_was_captured <= 1'b1;
            capture_wiring <= wiring_data_in;
        end else begin
            wiring_valid_out <= 1'b1;
            wiring_data_out <= wiring_data_in;
        end
    end else begin
        wiring_valid_out <= 1'b0;
    end
end

assign wiring = enable ? capture_wiring : '0;

endmodule
`default_nettype wire
