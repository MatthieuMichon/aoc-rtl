`timescale 1ns/1ps
`default_nettype none

module light_display #(
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

assign instr_ready = 1'b1;

always_ff @(posedge clk) begin: dummy
    if (reset) begin
        count_done <= 1'b0;
        count_value <= '0;
    end else begin
        count_done <= instr_last;
        if (instr_ready && instr_valid) begin
            count_value <= count_value + $countones(instr_data);
        end
    end
end

endmodule
