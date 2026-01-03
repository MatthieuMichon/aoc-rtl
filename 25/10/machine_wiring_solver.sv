`timescale 1ns/1ps
`default_nettype none

module machine_wiring_solver #(
    parameter int MAX_WIRING_WIDTH,
    parameter int MAX_BUTTON_WIRINGS
)(
    input wire clk,
    // Decoded Line Contents
        output logic solver_ready,
        input wire end_of_line, // pulsed on valid cycle
        input wire wiring_valid,
        input wire [MAX_WIRING_WIDTH-1:0] wiring_data,
    // Solver Outputs
        output logic solving_done,
        output logic solution_valid,
        output logic [MAX_BUTTON_WIRINGS-1:0] solution_button_wirings
);

typedef logic [MAX_WIRING_WIDTH-1:0] wiring_t;
typedef logic [MAX_BUTTON_WIRINGS-1:0] button_wirings_t;
typedef enum logic {
    LIGHT = 1'b0,
    BUTTON = 1'b1
} wiring_type_t;
wiring_type_t wiring_sel;

wiring_t light_wiring;
wiring_t button_wiring;
//button_wirings_t button_wirings;

typedef enum logic [1:0] {
    CAPTURE_LIGHT_WIRING,
    CAPTURE_BUTTON_WIRINGS,
    UPDATE_COMBINATIONS,
    RUN_SOLVER
} state_t;
state_t current_state = CAPTURE_LIGHT_WIRING, next_state;

always_ff @(posedge clk) current_state <= next_state;

always_comb begin: state_logic
    unique case (current_state)
        CAPTURE_LIGHT_WIRING: begin
            if (!wiring_valid) begin: input_decoding_pending
                next_state = CAPTURE_LIGHT_WIRING;
            end else begin
                next_state = CAPTURE_BUTTON_WIRINGS;
            end
        end
        CAPTURE_BUTTON_WIRINGS: begin
            if (!end_of_line) begin
                next_state = CAPTURE_BUTTON_WIRINGS;
            end else begin
                next_state = UPDATE_COMBINATIONS;
            end
        end
        UPDATE_COMBINATIONS: begin
            next_state = RUN_SOLVER;
        end
        RUN_SOLVER: begin
            if (!solving_done) begin
                next_state = RUN_SOLVER;
            end else begin
                next_state = CAPTURE_LIGHT_WIRING;
            end
        end
    endcase
end

always_comb begin: output_update
    wiring_sel = LIGHT;
    unique case (current_state)
        CAPTURE_LIGHT_WIRING: begin
            solver_ready = 1'b1;
        end
        CAPTURE_BUTTON_WIRINGS: begin
            solver_ready = 1'b1;
            wiring_sel = BUTTON;
        end
        UPDATE_COMBINATIONS: begin
            solver_ready = 1'b0;
        end
        RUN_SOLVER: begin
            solver_ready = 1'b0;
        end
    endcase
end

always_ff @(posedge clk) begin: wiring_data_fanout
    unique case (wiring_sel)
        LIGHT: begin
            light_wiring <= wiring_data;
        end
        BUTTON: begin
            button_wiring <= wiring_data;
        end
    endcase
end

assign solving_done = 1'b0;
assign solution_valid = 1'b0;
assign solution_button_wirings = '0;

wire _unused_ok = 1'b0 && &{1'b0,
    wiring_sel,
    light_wiring,
    button_wiring,
    1'b0};
endmodule
`default_nettype wire
