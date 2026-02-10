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

localparam int OPERATION_WIDTH = 2;
localparam int POSITION_WIDTH = 12;

typedef logic [OPERATION_WIDTH-1:0] operation_t;
typedef logic [POSITION_WIDTH-1:0] position_t;
typedef enum operation_t {
    TURN_OFF = 2'b00,
    TOGGLE = 2'b01,
    TURN_ON = 2'b11
} operations_t;

logic last, valid;
operation_t operation;
position_t start_row, start_col, end_row, end_col;
position_t row_count;

assign {last, valid, operation, start_row, start_col, end_row, end_col} = instr_data;

always_ff @(posedge clk) begin: dummy_flow_control
    if (reset) begin
        instr_ready <= 1'b0;
        row_count <= '0;
    end else begin
        if (instr_ready && instr_valid) begin
            instr_ready <= 1'b0;
            row_count <= end_row - start_row;
        end else if (row_count > 0) begin
            row_count <= row_count - 1;
        end else begin
            instr_ready <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    assert (!(instr_ready && instr_valid && (start_row > end_row)))
        else $error("Unexpected start_row vs end_row");
end

always_ff @(posedge clk) begin: finish_condition
    if (reset) begin
        count_done <= 1'b0;
        count_value <= '0;
    end else begin
        if (instr_ready && instr_valid) begin
            count_done <= instr_last;
            count_value <= count_value + 1'b1;
        end
    end
end

wire _unused_ok = 1'b0 && &{1'b0,
    last, valid, operation, start_col, end_col,
    1'b0};

endmodule
