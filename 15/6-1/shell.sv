`timescale 1ns/1ps
`default_nettype none

module shell;
localparam int JTAG_USER_ID = 4;

logic tck, tms, tdi, tdo, drck;
logic test_logic_reset, run_test_idle, ir_is_user;
logic capture_dr, shift_dr, update_dr;
logic conf_clk;

BSCANE2 #(.JTAG_CHAIN(JTAG_USER_ID)) bscan_i (
    // raw JTAG signals
        .TCK(tck),
        .TMS(tms),
        .TDI(tdi),
        .TDO(tdo), // muxed by TAP if IR matches USER(JTAG_CHAIN)
        .DRCK(drck), // tck when SEL and (CAPTURE or SHIFT) else '1'
    // TAP controller states
        .RESET(test_logic_reset),
        .RUNTEST(run_test_idle),
        .SEL(ir_is_user),
        .CAPTURE(capture_dr),
        .SHIFT(shift_dr),
        .UPDATE(update_dr));

USR_ACCESSE2 usr_access_i (
    .CFGCLK(conf_clk)
);

user_logic user_logic_i (
    // raw JTAG signals
        .tck(tck),
        .tms(tms),
        .tdi(tdi),
        .tdo(tdo),
    // TAP controller states
        .test_logic_reset(test_logic_reset),
        .run_test_idle(run_test_idle),
        .ir_is_user(ir_is_user),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
        .update_dr(update_dr),
    // 'fast' clock
        .conf_clk(conf_clk));

endmodule
`default_nettype wire
