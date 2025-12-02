`timescale 1ns/1ps
`default_nettype none
module shell;
localparam int USER4_CMD = 4;

typedef struct packed {
    logic [8-1:0] cmd;
    logic [8-1:0] data;
} tap_data_t;
tap_data_t tap_data;

logic [16-1:0] rotations;
logic tck, tdi, tdo;
logic [8-1:0] updated_tap_data;
logic tap_valid;

always_ff @(posedge tck) begin: shift_catpured_tap_data
    if (tap_ir_is_user4) begin
        if (state_is_capture_dr) begin
            updated_tap_data <= rotations;
        end else if (state_is_shift_dr) begin
            updated_tap_data <= {1'b1, updated_tap_data[8-1:1]};
        end
    end
end

logic state_is_test_logic_reset, state_is_run_test_idle, tap_ir_is_user4,
    state_is_capture_dr, state_is_shift_dr, state_is_update_dr;

assign tdo = updated_tap_data[0];

BSCANE2 #(.JTAG_CHAIN(USER4_CMD)) bscan_i (
    // raw JTAG signals
    .TCK(tck), .TDI(tdi), .TDO(tdo),
    // TAP controller state
    .RESET(state_is_test_logic_reset),
    .RUNTEST(state_is_run_test_idle),
    .SEL(tap_ir_is_user4),
    .CAPTURE(state_is_capture_dr),
    .SHIFT(state_is_shift_dr),
    .UPDATE(state_is_update_dr)
);

always_ff @(posedge tck) begin: shift_updated_tap_data
    if (state_is_test_logic_reset) begin
        tap_data <= '0;
        tap_valid <= 1'b0;
    end else if (tap_ir_is_user4) begin
        if (state_is_shift_dr) begin
            tap_data <= {tdi, tap_data[16-1:1]};
        end
        tap_valid <= state_is_update_dr;
    end
end

localparam logic [8-1:0] WRITE_ASCII_BYTE = 8'hA0;

logic write_ascii_byte, commit_ascii_bytes, read_next_ascii_byte;

always_ff @(posedge tck) begin: decode_tap_cmd
    write_ascii_byte <= 1'b0;
    if (tap_valid) begin
        unique case (tap_data.cmd)
            WRITE_ASCII_BYTE: begin
                write_ascii_byte <= 1'b1;
            end
            default: begin end
        endcase
    end
end

logic [16-1:0] right_steps;
logic steps_valid;

ascii_decoder ascii_decoder_i (
    .clk(tck),
    .ascii_data(tap_data.data),
    .ascii_valid(write_ascii_byte),
    .right_steps(right_steps),
    .right_steps_valid(steps_valid)
);

logic [4-1:0] dozens, units_;
localparam int CARRY = 1;

always_ff @(posedge tck) begin: bcd_two_digits
    if (state_is_test_logic_reset) begin
        dozens <= 4'h5; // initial value of 50 according to problem statement
        units_ <= 4'h0;
    end else if (steps_valid) begin
        if (units_ + right_steps[4-1-:4] > 9) begin: carry_units
            units_ <= units_ + right_steps[4-1-:4] - 10;
            if (dozens + right_steps[12-1-:4] + CARRY > 9) begin: carry_dozens_and_units
                dozens <= dozens + right_steps[12-1-:4] + CARRY - 10;
            end else begin
                dozens <= dozens + right_steps[12-1-:4];
            end
        end else begin
            units_ <= units_ + right_steps[4-1:0];
            if (dozens + right_steps[12-1-:4] > 9) begin: carry_dozens_only
                dozens <= dozens + right_steps[12-1-:4] - 10;
            end else begin
                dozens <= dozens + right_steps[12-1-:4];
            end
        end
    end
end

assign rotations = {4'h3, dozens, 4'h3, units_};

endmodule
`default_nettype wire
