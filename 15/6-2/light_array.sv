`timescale 1ns/1ps
`default_nettype none

module light_array #(
    parameter int INSTRUCTION_WIDTH,
    parameter int RESULT_WIDTH
)(
    input wire clk,
    input wire reset,
    // Instruction Data
        input wire instr_last,
        output logic instr_ready,
        input wire instr_valid,
        input wire [INSTRUCTION_WIDTH-1:0] instr_data,
    // Final Lit Lights
        output logic count_done,
        output logic [RESULT_WIDTH-1:0] count_value
);

localparam int OPERATION_WIDTH = 2;
localparam int POSITION_WIDTH = 12;
localparam int CMD_DATA_WIDTH = OPERATION_WIDTH + 4 * POSITION_WIDTH;
localparam int BANKS = 1;

typedef logic [RESULT_WIDTH-1:0] intensity_t;
typedef logic [CMD_DATA_WIDTH-1:0] cmd_t;

logic [BANKS-1:0] instr_ready_array;
logic instr_valid_local;
logic [BANKS:0] cascade_valid_array;
logic cascade_valid_array_entry; // Icarus Verilog
intensity_t [BANKS:0] cascade_intensity_array;

cmd_t cmd_data;

logic last_cmd_pending;

assign instr_ready = &instr_ready_array;
assign instr_valid_local = instr_valid && (&instr_ready_array);

always_ff @(posedge clk) begin: wait_last_cmd_done
    if (reset) begin
        last_cmd_pending <= 1'b0;
        cascade_valid_array_entry <= 1'b0;
    end else begin
        if (instr_last && instr_ready && instr_valid) begin
            last_cmd_pending <= 1'b1;
        end else if (last_cmd_pending && instr_ready) begin
            last_cmd_pending <= 1'b0;
            cascade_valid_array_entry <= 1'b1;
        end
    end
end
// Icarus Verilog Icarus Verilog (and the Verilog standard) forbids mixing
// procedural with continuous assignments.
assign cascade_valid_array[0] = cascade_valid_array_entry;
assign cascade_intensity_array[0] = '0;

assign cmd_data = CMD_DATA_WIDTH'(instr_data);

genvar i;
generate for (i = 0; i < BANKS; i++) begin

    light_bank #(
        .CMD_DATA_WIDTH(CMD_DATA_WIDTH),
        .INTENSITY_WIDTH(RESULT_WIDTH),
        .START_LIGHT_INDEX(0),
        .STOP_LIGHT_INDEX(5)
    )light_bank_i(
        .clk(clk),
        .reset(reset),
        // Instruction Data
            .cmd_last(instr_last),
            .cmd_ready(instr_ready_array[i]),
            .cmd_valid(instr_valid_local),
            .cmd_data(cmd_data),
        // Intensity Total
            .cascade_in_valid(cascade_valid_array[i]),
            .cascade_in_intensity(cascade_intensity_array[i]),
            .cascade_out_valid(cascade_valid_array[1+i]),
            .cascade_out_intensity(cascade_intensity_array[1+i])
    );
end endgenerate

always_ff @(posedge clk) begin: register_result
    count_done <= !reset && cascade_valid_array[BANKS];
    count_value <= cascade_intensity_array[BANKS];
end

wire _unused_ok = 1'b0 && &{1'b0,
    instr_data,
    1'b0};

endmodule
`default_nettype wire
