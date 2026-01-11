`timescale 1ns/1ps
`default_nettype none

module tap_encoder #(
    parameter int DATA_WIDTH
)(
    input wire tck,
    output logic tdo,
    input wire test_logic_reset,
    input wire ir_is_user,
    input wire capture_dr,
    input wire shift_dr,

    input wire [DATA_WIDTH-1:0] data,
    input wire valid
);

typedef logic [DATA_WIDTH-1:0] data_t;
data_t data_r = '0, shift_reg = '0;

always_ff @(posedge tck) begin: capture_data
    if (valid) begin
        data_r <= data;
    end
end

always_ff @(posedge tck) begin: shift_tdo
    if (test_logic_reset) begin
        shift_reg <= '0;
    end else if (ir_is_user) begin
        if (capture_dr) begin
            shift_reg <= data_r;
        end else if (shift_dr) begin
            shift_reg <= {1'b1, shift_reg[DATA_WIDTH-1:1]};
        end
    end
end

assign tdo = shift_reg[0];

endmodule
`default_nettype wire
