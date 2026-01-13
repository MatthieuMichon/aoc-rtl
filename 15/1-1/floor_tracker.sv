`timescale 1ns/1ps
`default_nettype none

module floor_tracker #(
    parameter int RESULT_WIDTH
)(
    input wire clk,
    input wire reset,
    // Inbound Byte Stream
        input wire inbound_valid,
        input wire [8-1:0] inbound_data,
    // Decoded Line Contents
        output logic outbound_valid = 1'b0,
        output logic [RESULT_WIDTH-1:0] outbound_data
);

// from `man ascii`
typedef enum byte {
    LF_CHAR = 8'h0A,
    L_PAREN_CHAR = 8'h28, // `(`
    R_PAREN_CHAR = 8'h29 // `)`
} char_t;

logic end_of_file = 1'b0, dir_valid = 1'b0, dir_up_down = 1'b0;

always_ff @(posedge clk) begin
    dir_valid <= 1'b0;
    if (inbound_valid) begin
        unique case (inbound_data)
            L_PAREN_CHAR: begin
                dir_up_down <= 1'b1;
                dir_valid <= 1'b1;
            end
            R_PAREN_CHAR: begin
                dir_up_down <= 1'b0;
                dir_valid <= 1'b1;
            end
            LF_CHAR: begin
                end_of_file <= 1'b1;
            end
            default: begin
            end
        endcase
    end
end

always_ff @(posedge clk) begin
    if (reset) begin
        outbound_valid <= 1'b0;
        outbound_data <= '0;
    end else begin
        outbound_valid <= end_of_file;
        if (dir_valid) begin
            if (dir_up_down) begin
                outbound_data <= outbound_data + 1'b1;
            end else begin
                outbound_data <= outbound_data - 1'b1;
            end
        end
    end
end

endmodule
`default_nettype wire
