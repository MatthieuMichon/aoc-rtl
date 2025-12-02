`timescale 1ns/1ps
`default_nettype none

module ascii_decoder(
    input wire clk,
    input wire [8-1:0] ascii_data,
    input wire ascii_valid,
    output logic [2*8-1:0] right_steps, // ASCII chars
    output logic right_steps_valid
);

// from `man ascii`
localparam byte L_CHAR = 8'h4C, R_CHAR = 8'h52,
    ZERO_CHAR = 8'h30, NINE_CHAR = 8'h39, LF_CHAR = 8'h0A;

// 100 steps: only the two last digits are meaningful
logic [8-1:0] dozens, units_;

always_ff @(posedge clk) begin: ascii_digit_capture
    if (ascii_valid) begin
        if ((ascii_data < ZERO_CHAR) || (ascii_data > NINE_CHAR)) begin
            dozens <= '0;
            units_ <= '0;
        end else begin
            dozens <= units_;
            units_ <= ascii_data;
        end
    end
end

// Assumes several cycles between last digit and newline
always_ff @(posedge clk) begin: ascii_byte_decoder
    right_steps_valid <= 1'b0;
    if (ascii_valid) begin
        unique case (ascii_data)
            LF_CHAR: right_steps_valid <= 1'b1;
            L_CHAR: begin
                if ((dozens == ZERO_CHAR) && (units_ == ZERO_CHAR))
                    right_steps <= {dozens, units_};
                else begin
                    if (units_ == ZERO_CHAR) begin
                        right_steps[16-1:8] <= (1 + NINE_CHAR - dozens) + ZERO_CHAR;
                        right_steps[8-1:0] <= units_;
                    end else begin
                        right_steps[16-1:8] <= (NINE_CHAR - dozens) + ZERO_CHAR;
                        right_steps[8-1:0] <= (NINE_CHAR - units_) + ZERO_CHAR;
                    end
                end
            end
            R_CHAR: right_steps <= {dozens, units_};
            default:;
        endcase
    end
end

endmodule
`default_nettype wire
