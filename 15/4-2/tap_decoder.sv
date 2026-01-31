`timescale 1ns/1ps
`default_nettype none

module tap_decoder #(
    parameter int INBOUND_DATA_WIDTH,
    parameter int UPSTREAM_BYPASS_BITS
)(
    // JTAG TAP Controller Signals
        input wire tck,
        input wire tms,
        input wire tdi,
        input wire test_logic_reset,
        input wire ir_is_user,
        input wire shift_dr,
        input wire update_dr,
    // Deserialized Data
        output logic inbound_alignment_error,
        output logic inbound_valid,
        output logic [INBOUND_DATA_WIDTH-1:0] inbound_data
);

typedef logic [INBOUND_DATA_WIDTH-1:0] data_t;

int shift_count = 0;
logic reset_condition;

assign reset_condition = test_logic_reset || !shift_dr;

always_ff @(posedge tck) begin: shift_tdi
    if (reset_condition) begin
        inbound_valid <= 1'b0;
        inbound_data <= '0;
        shift_count <= 0;
    end else if (ir_is_user && shift_dr) begin
        inbound_data <= {tdi, inbound_data[$left(inbound_data):1]};
        if ((1 + shift_count) < INBOUND_DATA_WIDTH + UPSTREAM_BYPASS_BITS) begin
            inbound_valid <= 1'b0;
            shift_count <= shift_count + 1;
        end else begin
            inbound_valid <= 1'b1;
            shift_count <= UPSTREAM_BYPASS_BITS;
        end
    end
end

always_ff @(posedge tck) begin: update
    if (test_logic_reset) begin
        inbound_alignment_error <= 1'b0;
    end else if (ir_is_user && update_dr && tms) begin
        if ((1 + shift_count) != INBOUND_DATA_WIDTH) begin
            inbound_alignment_error <= 1'b1;
        end
    end
end

endmodule
`default_nettype wire
