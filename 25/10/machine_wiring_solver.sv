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
logic reset_button_wiring_units;
logic run_solver;

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
    reset_button_wiring_units = 1'b0;
    wiring_sel = LIGHT;
    run_solver = 1'b0;
    unique case (current_state)
        CAPTURE_LIGHT_WIRING: begin
            solver_ready = 1'b1;
            reset_button_wiring_units = 1'b1;
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
            run_solver = 1'b1;
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

logic wiring_valid_chain[0:MAX_BUTTON_WIRINGS]; // +1 for exit node
wiring_t wiring_data_chain[0:MAX_BUTTON_WIRINGS]; // +1 for exit node
logic [MAX_BUTTON_WIRINGS-1:0] enable;
wiring_t wiring[0:MAX_BUTTON_WIRINGS-1];

assign wiring_valid_chain[0] = wiring_valid && (wiring_sel == BUTTON);
assign wiring_data_chain[0] = wiring_data;

always_ff @(posedge clk) begin
    if (!run_solver) begin
        enable <= '0;
    end else begin
        enable <= enable + 1'b1;
    end
end

genvar i;
generate for (i = 0; i < MAX_BUTTON_WIRINGS; i++) begin: button_wiring_gen

    button_wiring #(
        .MAX_WIRING_WIDTH(MAX_WIRING_WIDTH)
    ) button_wiring_i (
        .clk(clk),
        .reset(reset_button_wiring_units), // clear wiring configuration
        // Configuration Daisy Chain
            .wiring_valid_in(wiring_valid_chain[i]),
            .wiring_data_in(wiring_data_chain[i]),
            .wiring_valid_out(wiring_valid_chain[i+1]),
            .wiring_data_out(wiring_data_chain[i+1]),
        // Wiring State
            .enable(enable[i]),
            .wiring(wiring[i])
    );

end endgenerate

wiring_t xorrr;

// always_ff @(posedge clk) solution_button_wirings <= wiring.xor(); not supported by Icarus Verilog :'(

initial begin
    solution_button_wirings = '0;
end
always_comb begin
    solution_button_wirings = '0; // Initialize to zero (neutral element for XOR)
    for (int i = 0; i < MAX_BUTTON_WIRINGS; i++) begin
        solution_button_wirings = solution_button_wirings ^ wiring[i];
    end
end

assign solving_done = 1'b0;
assign solution_valid = 1'b0;
//assign solution_button_wirings = '0;

wire _unused_ok = 1'b0 && &{1'b0,
    wiring_sel,
    light_wiring,
    button_wiring,
    xorrr,
    1'b0};
endmodule
`default_nettype wire
