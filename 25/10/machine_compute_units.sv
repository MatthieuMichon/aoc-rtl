`timescale 1ns/1ps
`default_nettype none

module machine_compute_units #(
    parameter int MAX_WIRING_WIDTH,
    parameter int MAX_BUTTON_WIRINGS,
    parameter int RESULT_WIDTH
) (
    input wire clk,
    // Decoded Line Contents
        input wire end_of_file,
        input wire end_of_line,
        input wire wiring_valid,
        input wire [MAX_WIRING_WIDTH-1:0] wiring_data,
    // Solver Outputs
        output logic compute_finished,
        output logic result_valid,
        output logic [RESULT_WIDTH-1:0] result_data
);

localparam int SOLVER_UNITS = 1;
typedef logic [MAX_WIRING_WIDTH-1:0] wiring_t;
typedef logic [MAX_BUTTON_WIRINGS-1:0] button_wirings_t;

logic [SOLVER_UNITS-1:0] solver_ready, solver_failed, solution_valid;
button_wirings_t solution_button_wirings [SOLVER_UNITS-1:0];

genvar i;
generate for (i = 0; i < SOLVER_UNITS; i++) begin
    machine_wiring_solver #(
        .MAX_WIRING_WIDTH(MAX_WIRING_WIDTH),
        .MAX_BUTTON_WIRINGS(MAX_BUTTON_WIRINGS)
    ) machine_wiring_solver_i (
        .clk(clk),
        // Decoded Line Contents
            .solver_ready(solver_ready[i]),
            .end_of_line(end_of_line),
            .wiring_valid(wiring_valid),
            .wiring_data(wiring_data),
        // Solver Outputs
            .solving_failed(solver_failed[i]),
            .solution_valid(solution_valid[i]),
            .solution_button_wirings(solution_button_wirings[i])
    );
end endgenerate

always_ff @(posedge clk) compute_finished <= end_of_file;
always_ff @(posedge clk) result_valid <= solution_valid[0];
always_ff @(posedge clk) result_data <= $countones(solution_button_wirings[0]);

wire _unused_ok = 1'b0 && &{1'b0,
    solver_ready,
    solver_failed,
    1'b0};

endmodule
`default_nettype wire
