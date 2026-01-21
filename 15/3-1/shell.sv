`timescale 1ns/1ps
`default_nettype none

module shell;
localparam int JTAG_USER_ID = 4;

logic tck, tms, tdi, tdo, drck;
logic test_logic_reset, run_test_idle, ir_is_user;
logic capture_dr, shift_dr, update_dr;

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
        .update_dr(update_dr));

`ifdef ILA
localparam int AXSS_WIDTH = 32;
typedef logic[AXSS_WIDTH-1:0] axss_t;

logic conf_clk, conf_clk_2x, axss_valid;
axss_t axss_data;

USR_ACCESSE2 (
    .CFGCLK(conf_clk),
    .DATAVALID(axss_valid),
    .DATA(axss_data)
);

logic fbclk, locked;

MMCME2_BASE #(
    .CLKIN1_PERIOD(16.667),
    .CLKFBOUT_MULT_F(16.0),
    .DIVCLK_DIVIDE(1),
    .CLKOUT0_DIVIDE_F(8.0)
) mmcm_i (
    .CLKIN1(conf_clk),
    .CLKOUT0(conf_clk_2x),
    .CLKFBOUT(fbclk),
    .CLKFBIN(fbclk),
    .PWRDWN(1'b0),
    .RST(1'b0),
    .LOCKED(locked)
);

logic [11-1:0] ila_signals;

assign ila_signals = {
    tck, tms, tdi, tdo,
    drck, test_logic_reset, run_test_idle,
    ir_is_user, capture_dr, shift_dr, update_dr};

bscan_ila bscan_ila_i (
    .clk(conf_clk_2x),
    .probe0(ila_signals)
);
`endif

endmodule
`default_nettype wire
