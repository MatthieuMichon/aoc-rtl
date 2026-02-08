`timescale 1ns/1ps
`default_nettype none

module tap_encoder #(
    parameter int OUTBOUND_DATA_WIDTH
)(
    // Deserialized Signals
        input  wire outbound_valid,
        input  wire [OUTBOUND_DATA_WIDTH-1:0] outbound_data,
    // JTAG TAP Controller Signals
        input  wire tck,
        input  wire test_logic_reset,
        input  wire ir_is_user,
        input  wire capture_dr,
        input  wire shift_dr,
        output logic tdo
);

typedef logic [OUTBOUND_DATA_WIDTH-1:0] data_t;
data_t data_r = '0, shift_reg = '0;

always_ff @(posedge tck) begin: capture_data_buffer
    if (outbound_valid) begin
        data_r <= outbound_data;
    end
end

always_ff @(posedge tck) begin: shift_logic_on_negedge
    if (test_logic_reset) begin
        shift_reg <= '0;
    end else if (ir_is_user) begin
        if (capture_dr) begin
            shift_reg <= data_r;
        end else if (shift_dr) begin
            shift_reg <= {1'b0, shift_reg[OUTBOUND_DATA_WIDTH-1:1]};
        end
    end
end

assign tdo = shift_reg[0];

endmodule
`default_nettype wire
