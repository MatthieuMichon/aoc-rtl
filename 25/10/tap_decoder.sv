`timescale 1ns/1ps
`default_nettype none

module tap_decoder #(
    parameter int DATA_WIDTH
)(
    input wire tck,
    input wire tdi,
    input wire test_logic_reset,
    input wire ir_is_user,
    input wire shift_dr,
    input wire update_dr,

    output logic valid,
    output logic [DATA_WIDTH-1:0] data
);

always_ff @(posedge tck) begin: shift_tdi
    if (ir_is_user && shift_dr) begin
        data <= {tdi, data[DATA_WIDTH-1:1]};
    end
end

initial begin
    valid = 1'b0;
end

always_ff @(posedge tck) begin: update
    if (test_logic_reset) begin
        valid <= 1'b0;
    end else begin
        valid <= ir_is_user && update_dr;
    end
end

endmodule
`default_nettype wire
