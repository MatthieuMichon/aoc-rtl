`timescale 1ns/1ps
`default_nettype none

module ascii_decoder (
    input wire clk,
    // Inbound Byte Stream
        input wire ascii_valid,
        input wire [8-1:0] ascii_data,
    // Decoded Line Contents
        output logic end_of_file, // held high
        output logic right_steps_valid,
        output logic [8-1:0] right_steps
);

// from `man ascii`
typedef enum byte {
    NULL_CHAR = 8'h00,
    LF_CHAR = 8'h0A,
    ZERO_CHAR = 8'h30, // `0`
    NINE_CHAR = 8'h39, // `9`
    L_CHAR = 8'h4C, // upper-case `L`
    R_CHAR = 8'h52 // upper-case `R`
} char_t;

// from `man ascii`
// localparam byte L_CHAR = 8'h4C, R_CHAR = 8'h52,
//     ZERO_CHAR = 8'h30, NINE_CHAR = 8'h39, LF_CHAR = 8'h0A;

localparam int DECIMAL_DIGITS_WIDTH = $clog2(10);
typedef logic [DECIMAL_DIGITS_WIDTH-1:0] digit_t;

logic ascii_data_is_digit;
assign ascii_data_is_digit = (ascii_data >= ZERO_CHAR) && (ascii_data <= NINE_CHAR);
digit_t dozens, units_;

typedef enum logic [2:0] {
    CAPTURE_DIRECTION,
    CAPTURE_DIGITS_CCW,
    CAPTURE_DIGITS_CW,
    PUSH_CCW_STEPS,
    PUSH_CW_STEPS
} state_t;

state_t current_state, next_state;
initial begin
    current_state = CAPTURE_DIRECTION;
end

always_ff @(posedge clk) begin: state_register
    current_state <= next_state;
end

always_comb begin: state_logic
    unique case (current_state)
        CAPTURE_DIRECTION: begin
            if (ascii_valid) begin
                if (ascii_data == L_CHAR) begin
                    next_state = CAPTURE_DIGITS_CCW;
                end else if (ascii_data == R_CHAR) begin
                    next_state = CAPTURE_DIGITS_CW;
                end else begin: unexpected_from_capture_dir
                    next_state = CAPTURE_DIRECTION;
                end
            end else begin
                next_state = CAPTURE_DIRECTION;
            end
        end
        CAPTURE_DIGITS_CCW: begin
            if (ascii_valid) begin
                if (ascii_data_is_digit) begin
                    next_state = CAPTURE_DIGITS_CCW;
                end else if (ascii_data == LF_CHAR) begin
                    next_state = PUSH_CCW_STEPS;
                end else begin: unexpected_from_capture_ccw
                    next_state = CAPTURE_DIRECTION;
                end
            end else begin
                next_state = CAPTURE_DIGITS_CCW;
            end
        end
        CAPTURE_DIGITS_CW: begin
            if (ascii_valid) begin
                if (ascii_data_is_digit) begin
                    next_state = CAPTURE_DIGITS_CW;
                end else if (ascii_data == LF_CHAR) begin
                    next_state = PUSH_CW_STEPS;
                end else begin: unexpected_from_capture_cw
                    next_state = CAPTURE_DIRECTION;
                end
            end else begin
                next_state = CAPTURE_DIGITS_CW;
            end
        end
        PUSH_CCW_STEPS: begin
            next_state = CAPTURE_DIRECTION;
        end
        PUSH_CW_STEPS: begin
            next_state = CAPTURE_DIRECTION;
        end
        default: begin
            next_state = CAPTURE_DIRECTION;
        end
    endcase
end

logic [8-1:0] steps;

always_comb begin: output_logic
    steps = DECIMAL_DIGITS_WIDTH'(10) * dozens + $bits(steps)'(units_);
    if (current_state == PUSH_CCW_STEPS) begin
        right_steps = 8'd100 - steps;
        right_steps_valid = 1'b1;
    end else if (current_state == PUSH_CW_STEPS) begin
        right_steps = steps;
        right_steps_valid = 1'b1;
    end else begin
        right_steps = '0;
        right_steps_valid = 1'b0;
    end
end

initial begin
    end_of_file = 1'b0;
end

always_ff @(posedge clk) begin: ascii_digit_capture
    if (ascii_valid) begin
        if (ascii_data_is_digit) begin
            dozens <= units_;
            units_ <= ascii_data[4-1:0];
        end else if (ascii_data == LF_CHAR) begin: do_nothing
        end else if (ascii_data == NULL_CHAR) begin: eof
            end_of_file <= 1'b1;
        end else begin
            dozens <= 0;
            units_ <= 0;
        end
    end
end

endmodule
`default_nettype wire
