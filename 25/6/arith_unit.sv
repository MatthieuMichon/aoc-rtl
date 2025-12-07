`timescale 1ns/1ps
`default_nettype none

module arith_unit #(
    parameter int ARG_DATA_WIDTH,
    parameter int PROBLEM_DATA_WIDTH
)(
    input wire clk,
    // Decoded signals
        input wire operand_valid,
        input wire operand_mult_add,
    // Argument readback
        input logic [ARG_DATA_WIDTH-1:0] rd_arg_data_row0,
        input logic [ARG_DATA_WIDTH-1:0] rd_arg_data_row1,
        input logic [ARG_DATA_WIDTH-1:0] rd_arg_data_row2,
    // Computed Value
        output logic problem_valid,
        output logic [PROBLEM_DATA_WIDTH-1:0] problem_data
);

logic operand_mult_add_gated;

always_ff @(posedge clk) begin
    if (operand_valid) begin
        operand_mult_add_gated <= operand_mult_add;
    end
end

typedef logic [PROBLEM_DATA_WIDTH-1:0] problem_t;
problem_t mult_problem, add_problem;

always_ff @(posedge clk) begin
    mult_problem <= rd_arg_data_row0 * rd_arg_data_row1 * rd_arg_data_row2;
    add_problem <= rd_arg_data_row0 + rd_arg_data_row1 + rd_arg_data_row2;
end

localparam int PIPELINE_STAGES = 3;
logic [PIPELINE_STAGES-1:0] problem_valid_sr;

always_ff @(posedge clk) begin
    problem_valid <= problem_valid_sr[PIPELINE_STAGES-1];
    problem_valid_sr <= {problem_valid_sr[PIPELINE_STAGES-2:0], operand_valid};
end

always_ff @(posedge clk) begin
    problem_data <= operand_mult_add_gated ? mult_problem : add_problem;
end

endmodule
`default_nettype wire
