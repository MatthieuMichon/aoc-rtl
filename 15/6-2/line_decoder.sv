`timescale 1ns/1ps
`default_nettype none

module line_decoder #(
    parameter int INBOUND_DATA_WIDTH,
    parameter int INSTRUCTION_WIDTH
)(
    input wire clk,
    input wire reset,
    // Deserialized Data
        input wire inbound_valid,
        input wire [INBOUND_DATA_WIDTH-1:0] inbound_data,
    // Normalized Data
        output logic end_of_file,
        output logic normalized_instr_valid,
        output logic [INSTRUCTION_WIDTH-1:0] normalized_instr_data
);

localparam int OPERATION_WIDTH = 2;
localparam int POSITION_WIDTH = 12;

typedef logic [INBOUND_DATA_WIDTH-1:0] inbound_data_t;
typedef logic [OPERATION_WIDTH-1:0] operation_t;
typedef logic [POSITION_WIDTH-1:0] position_t;
typedef enum inbound_data_t {
    NULL_CHAR = 8'h00,
    LF_CHAR = 8'h0A,
    SPACE_CHAR = 8'h20,
    COMA_CHAR = 8'h2C, // ','
    ZERO_CHAR = 8'h30, // '0'
    NINE_CHAR = 8'h39, // '9'
    F_CHAR = 8'h66, // lower-case 'f'
    O_CHAR = 8'h6F, // lower-case 'o'
    N_CHAR = 8'h6E, // lower-case 'n'
    T_CHAR = 8'h74 // lower-case 't'
} char_t;
typedef enum operation_t {
    TURN_OFF = 2'b00,
    TOGGLE = 2'b01,
    RESERVED = 2'b10,
    TURN_ON = 2'b11
} op_e;
typedef struct packed {
    op_e op;
    position_t start_row, start_col;
    position_t end_row, end_col;
} cmd_s;
typedef enum logic [2-1:0] {
    CAPTURE_START_ROW = 0,
    CAPTURE_START_COL = 1,
    CAPTURE_END_ROW = 2,
    CAPTURE_END_COL = 3
} state_t;

state_t current_state, next_state;
inbound_data_t prev_char;
position_t position;
cmd_s cmd;

function is_digit(inbound_data_t char);
    is_digit = char >= ZERO_CHAR && char <= NINE_CHAR;
endfunction

always_ff @(posedge clk) begin: register_prev
    if (reset) begin
        prev_char <= '0;
    end else if (inbound_valid) begin
        prev_char <= inbound_data;
    end
end

always_ff @(posedge clk) begin: capture_operation
    if (reset) begin
        cmd.op <= TURN_OFF;
    end else begin
        if (inbound_valid) begin
            unique case ({prev_char, inbound_data})
                {O_CHAR, F_CHAR}: cmd.op <= TURN_OFF;
                {T_CHAR, O_CHAR}: cmd.op <= TOGGLE;
                {O_CHAR, N_CHAR}: cmd.op <= TURN_ON;
                default: /* no-op */;
            endcase
        end
    end
end

always_ff @(posedge clk) begin: state_register
    if (reset) begin
        current_state <= CAPTURE_START_ROW;
    end else begin
        current_state <= next_state;
    end
end

always_comb begin: state_logic
    unique case (current_state)
        CAPTURE_START_ROW: begin
            if (inbound_valid && inbound_data == COMA_CHAR) begin
                next_state = CAPTURE_START_COL;
            end else begin
                next_state = CAPTURE_START_ROW;
            end
        end
        CAPTURE_START_COL: begin
            if (inbound_valid && inbound_data == SPACE_CHAR) begin
                next_state = CAPTURE_END_ROW;
            end else begin
                next_state = CAPTURE_START_COL;
            end
        end
        CAPTURE_END_ROW: begin
            if (inbound_valid && inbound_data == COMA_CHAR) begin
                next_state = CAPTURE_END_COL;
            end else begin
                next_state = CAPTURE_END_ROW;
            end
        end
        CAPTURE_END_COL: begin
            if (normalized_instr_valid) begin
                next_state = CAPTURE_START_ROW;
            end else begin
                next_state = CAPTURE_END_COL;
            end
        end
        default: next_state = CAPTURE_START_ROW;
    endcase
end

always_ff @(posedge clk) begin: decimal_accumulator
    if (reset) begin
        position <= '0;
    end else if (inbound_valid) begin
        if (!is_digit(prev_char) && is_digit(inbound_data)) begin: first_digit
            position <= POSITION_WIDTH'(inbound_data - ZERO_CHAR);
        end else if (is_digit(prev_char) && is_digit(inbound_data)) begin: next_digit
            position <= 10 * position + POSITION_WIDTH'(inbound_data - ZERO_CHAR);
        end
    end
end

always_ff @(posedge clk) begin: position_fan_out
    if (reset) begin
        cmd.start_row <= '0;
        cmd.start_col <= '0;
        cmd.end_row <= '0;
        cmd.end_col <= '0;
    end else if (inbound_valid) begin
        unique case (current_state)
            CAPTURE_START_ROW: cmd.start_row <= position;
            CAPTURE_START_COL: cmd.start_col <= position;
            CAPTURE_END_ROW: cmd.end_row <= position;
            CAPTURE_END_COL: cmd.end_col <= position;
            default: /* no-op */;
        endcase
    end
end

always_ff @(posedge clk) begin: output_ctrl
    if (reset) begin
        end_of_file <= 1'b0;
        normalized_instr_valid <= 1'b0;
    end else begin
        normalized_instr_valid <= 1'b0;
        if (inbound_valid) begin
            end_of_file <= (inbound_data == NULL_CHAR);
            normalized_instr_valid <= (prev_char == LF_CHAR);
        end
    end
end

assign normalized_instr_data = cmd;

endmodule
`default_nettype wire
