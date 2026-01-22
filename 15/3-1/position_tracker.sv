`timescale 1ns/1ps
`default_nettype none

module position_tracker #(
    parameter int POSTION_WIDTH
) (
    input wire clk,
    input wire reset,
    // Decoded Data
        input wire shift_valid,
        input wire [4-1:0] shift_direction,
    // Position Data
        output logic pos_error,
        output logic pos_change,
        output logic [POSTION_WIDTH-1:0] pos_x,
        output logic [POSTION_WIDTH-1:0] pos_y
);

typedef enum logic [4-1:0] {
    N_DIR = 4'b1000,
    E_DIR = 4'b0100,
    S_DIR = 4'b0010,
    W_DIR = 4'b0001
} dir_t;

always_ff @(posedge clk) begin
    if (reset) begin
        pos_error <= 1'b0;
        pos_change <= 1'b0;
        pos_x <= '0;
        pos_y <= '0;
    end else begin
        pos_change <= shift_valid;
        if (shift_valid) begin
            unique case (shift_direction)
                N_DIR: pos_y <= pos_y + 1'b1;
                E_DIR: pos_x <= pos_x + 1'b1;
                S_DIR: pos_y <= pos_y - 1'b1;
                W_DIR: pos_x <= pos_x - 1'b1;
                default: pos_error <= 1'b1;
            endcase
        end
    end
end

endmodule
`default_nettype wire
