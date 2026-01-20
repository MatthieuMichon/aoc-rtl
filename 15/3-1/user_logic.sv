`timescale 1ns/1ps
`default_nettype none

module user_logic (
    // raw JTAG signals
        input wire tck,
        input wire tms,
        input wire tdi,
        output logic tdo,
    // TAP controller states
        input wire test_logic_reset,
        input wire ir_is_user,
        input wire run_test_idle,
        input wire capture_dr,
        input wire shift_dr,
        input wire update_dr
);

assign tdo = tdi;

wire _unused_ok = 1'b0 && &{1'b0,
    tck,
    tms,
    tdi,
    test_logic_reset,
    ir_is_user,
    run_test_idle,
    capture_dr,
    shift_dr,
    update_dr,

    1'b0};

endmodule
`default_nettype wire
