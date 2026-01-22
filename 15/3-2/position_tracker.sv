`timescale 1ns/1ps
`default_nettype none

module position_tracker #(
    parameter int POSITION_WIDTH
) (
    input wire clk,
    input wire reset,
    // Decoded Data
        input wire shift_valid,
        input wire [4-1:0] shift_direction,
    // Position Data
        output logic pos_error,
        output logic pos_change,
        output logic [POSITION_WIDTH-1:0] pos_x,
        output logic [POSITION_WIDTH-1:0] pos_y
);

typedef logic [POSITION_WIDTH-1:0] position_t;

typedef enum logic [4-1:0] {
    N_DIR = 4'b1000,
    E_DIR = 4'b0100,
    S_DIR = 4'b0010,
    W_DIR = 4'b0001
} dir_t;

logic is_robo_santa_next, santa_pos_change, robo_santa_pos_change;
position_t santa_x, santa_y, robo_santa_x, robo_santa_y;

always_ff @(posedge clk) begin: agent_pos_update
    if (reset) begin
        pos_error <= 1'b0;
        is_robo_santa_next <= 1'b0;
        santa_pos_change <= 1'b0;
        robo_santa_pos_change <= 1'b0;
        santa_x <= '0;
        santa_y <= '0;
        robo_santa_x <= '0;
        robo_santa_y <= '0;
    end else begin
        santa_pos_change <= 1'b0;
        robo_santa_pos_change <= 1'b0;
        if (shift_valid) begin
            if (!is_robo_santa_next) begin: santa_agent_pos_update
                santa_pos_change <= 1'b1;
                unique case (shift_direction)
                    N_DIR: santa_y <= santa_y + 1'b1;
                    E_DIR: santa_x <= santa_x + 1'b1;
                    S_DIR: santa_y <= santa_y - 1'b1;
                    W_DIR: santa_x <= santa_x - 1'b1;
                    default: pos_error <= 1'b1;
                endcase
            end else begin: robo_santa_agent_pos_update
                robo_santa_pos_change <= 1'b1;
                unique case (shift_direction)
                    N_DIR: robo_santa_y <= robo_santa_y + 1'b1;
                    E_DIR: robo_santa_x <= robo_santa_x + 1'b1;
                    S_DIR: robo_santa_y <= robo_santa_y - 1'b1;
                    W_DIR: robo_santa_x <= robo_santa_x - 1'b1;
                    default: pos_error <= 1'b1;
                endcase
            end
            is_robo_santa_next <= ~is_robo_santa_next;
        end
    end
end

logic zero_position_sent;

always_ff @(posedge clk) begin: output_pos_update
    if (reset) begin
        pos_change <= 1'b0;
        zero_position_sent <= 1'b0;
    end else begin
        if (!zero_position_sent) begin
            pos_change <= 1'b1;
            pos_x <= '0;
            pos_y <= '0;
            zero_position_sent <= 1'b1;
        end else if (santa_pos_change) begin
            pos_change <= 1'b1;
            pos_x <= santa_x;
            pos_y <= santa_y;
        end else if (robo_santa_pos_change) begin
            pos_change <= 1'b1;
            pos_x <= robo_santa_x;
            pos_y <= robo_santa_y;
        end else begin
            pos_change <= 1'b0;
        end
    end
end

endmodule
`default_nettype wire
