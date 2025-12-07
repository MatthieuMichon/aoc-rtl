`timescale 1ns/1ps
`default_nettype none

module arith_unit #(
    parameter int ARG_ROW_WIDTH,
    parameter int ARG_DATA_WIDTH,
    parameter int PROBLEM_DATA_WIDTH
)(
    input wire clk,
    // Decoded signals
        input wire [ARG_ROW_WIDTH-1:0] arg_row,
        input wire operand_valid,
        input wire operand_mult_add,
    // Argument readback
        input wire [ARG_DATA_WIDTH-1:0] rd_arg_data_row0,
        input wire [ARG_DATA_WIDTH-1:0] rd_arg_data_row1,
        input wire [ARG_DATA_WIDTH-1:0] rd_arg_data_row2,
        input wire [ARG_DATA_WIDTH-1:0] rd_arg_data_row3,
        input wire [ARG_DATA_WIDTH-1:0] rd_arg_data_row4,
        input wire [ARG_DATA_WIDTH-1:0] rd_arg_data_row5,
        input wire [ARG_DATA_WIDTH-1:0] rd_arg_data_row6,
        input wire [ARG_DATA_WIDTH-1:0] rd_arg_data_row7,
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
problem_t mult_problem[1:8], add_problem[1:8];
problem_t sel_mult_problem, sel_add_problem;

always_ff @(posedge clk) begin
    mult_problem[1] <= rd_arg_data_row0;
    mult_problem[2] <= rd_arg_data_row0 * rd_arg_data_row1;
    mult_problem[3] <= rd_arg_data_row0 * rd_arg_data_row1 * rd_arg_data_row2;
    mult_problem[4] <= rd_arg_data_row0 * rd_arg_data_row1 * rd_arg_data_row2 * rd_arg_data_row3;
    mult_problem[5] <= rd_arg_data_row0 * rd_arg_data_row1 * rd_arg_data_row2 * rd_arg_data_row3 * rd_arg_data_row4;
    mult_problem[6] <= rd_arg_data_row0 * rd_arg_data_row1 * rd_arg_data_row2 * rd_arg_data_row3 * rd_arg_data_row4 * rd_arg_data_row5;
    mult_problem[7] <= rd_arg_data_row0 * rd_arg_data_row1 * rd_arg_data_row2 * rd_arg_data_row3 * rd_arg_data_row4 * rd_arg_data_row5 * rd_arg_data_row6;
    mult_problem[8] <= rd_arg_data_row0 * rd_arg_data_row1 * rd_arg_data_row2 * rd_arg_data_row3 * rd_arg_data_row4 * rd_arg_data_row5 * rd_arg_data_row6 * rd_arg_data_row7;
    add_problem[1] <= rd_arg_data_row0;
    add_problem[2] <= rd_arg_data_row0 + rd_arg_data_row1;
    add_problem[3] <= rd_arg_data_row0 + rd_arg_data_row1 + rd_arg_data_row2;
    add_problem[4] <= rd_arg_data_row0 + rd_arg_data_row1 + rd_arg_data_row2 + rd_arg_data_row3;
    add_problem[5] <= rd_arg_data_row0 + rd_arg_data_row1 + rd_arg_data_row2 + rd_arg_data_row3 + rd_arg_data_row4;
    add_problem[6] <= rd_arg_data_row0 + rd_arg_data_row1 + rd_arg_data_row2 + rd_arg_data_row3 + rd_arg_data_row4 + rd_arg_data_row5;
    add_problem[7] <= rd_arg_data_row0 + rd_arg_data_row1 + rd_arg_data_row2 + rd_arg_data_row3 + rd_arg_data_row4 + rd_arg_data_row5 + rd_arg_data_row6;
    add_problem[8] <= rd_arg_data_row0 + rd_arg_data_row1 + rd_arg_data_row2 + rd_arg_data_row3 + rd_arg_data_row4 + rd_arg_data_row5 + rd_arg_data_row6 + rd_arg_data_row7;
end

always_ff @(posedge clk) begin
    sel_mult_problem <= mult_problem[arg_row];
    sel_add_problem <= add_problem[arg_row];
end
localparam int PIPELINE_STAGES = 3;
logic [PIPELINE_STAGES-1:0] problem_valid_sr;

always_ff @(posedge clk) begin
    problem_valid <= problem_valid_sr[PIPELINE_STAGES-1];
    problem_valid_sr <= {problem_valid_sr[PIPELINE_STAGES-2:0], operand_valid};
end

always_ff @(posedge clk) begin
    problem_data <= operand_mult_add_gated ? sel_mult_problem : sel_add_problem;
end

endmodule
`default_nettype wire
