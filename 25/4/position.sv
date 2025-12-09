`timescale 1ns/1ps
`default_nettype none

module arg_stores #(
    parameter int ROW,
    parameter int COL
)(
    input wire clk,
    // Configuration Daisy Chain
        input wire [8-1:0] byte_data_in,
        input wire byte_valid_in,
        output logic [8-1:0] byte_data_out,
        output logic byte_valid_out,
    // Neighbor State
        output logic has_roll_of_paper,
        input wire [9-1:0] neighbors,
        input wire has_forklift_clearance_in,
        output logic has_forklift_clearance_out
);

endmodule
`default_nettype wire
