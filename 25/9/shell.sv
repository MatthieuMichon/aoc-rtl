`timescale 1ns/1ps
`default_nettype none

module shell;
localparam int JTAG_USER_ID = 4;

logic tck, tdi, tdo;
logic test_logic_reset, ir_is_user, capture_dr, shift_dr, update_dr;

BSCANE2 #(.JTAG_CHAIN(JTAG_USER_ID)) bscan_i (
    // raw JTAG signals
        .TCK(tck),
        .TDI(tdi),
        .TDO(tdo), // muxed by TAP if IR matches USER(JTAG_CHAIN)
    // TAP controller states
        .RESET(test_logic_reset),
        .SEL(ir_is_user),
        .CAPTURE(capture_dr),
        .SHIFT(shift_dr),
        .UPDATE(update_dr));

user_logic user_logic_i (
    // BSCAN signals
        .tck(tck),
        .tdi(tdi),
        .tdo(tdo),
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
        .update_dr(update_dr));

endmodule
`default_nettype wire
