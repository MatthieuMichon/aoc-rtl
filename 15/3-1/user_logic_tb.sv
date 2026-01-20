`timescale 1ps/1ps
`default_nettype none

module user_logic_tb;

localparam int RESULT_WIDTH = 32;

localparam int SEEK_SET = 0;
localparam int SEEK_END = 2;

localparam int IR_LENGTH_ARM_DAP = 4;
localparam logic [IR_LENGTH_ARM_DAP-1:0] ARM_DAP_IR = 4'b0001;
localparam int IR_LENGTH_7_SERIES = 6;
localparam int IR_LENGTH = IR_LENGTH_ARM_DAP + IR_LENGTH_7_SERIES;
typedef logic [IR_LENGTH-1:0] ir_t;
localparam ir_t IR_USER4 = {ARM_DAP_IR, 6'b100011};

logic tck, tms  = 1'b1, tdi = 1'b1, tdo;
logic test_logic_reset, run_test_idle, ir_is_user = 1'b0, capture_dr, shift_dr, update_dr;

initial begin: tck_clock_gen
    tck = 0;
    forever #1 tck = ~tck;
end

typedef enum {
    TEST_LOGIC_RESET,
    RUN_TEST_IDLE,
    SELECT_DR_SCAN, SELECT_IR_SCAN,
    CAPTURE_DR, SHIFT_DR, EXIT1_DR, PAUSE_DR, EXIT2_DR, UPDATE_DR,
    CAPTURE_IR, SHIFT_IR, EXIT1_IR, PAUSE_IR, EXIT2_IR, UPDATE_IR
} state_t;

state_t current_state = TEST_LOGIC_RESET;

task automatic run_state_hw_jtag(state_t next_tap_state);
    unique case (next_tap_state)
        TEST_LOGIC_RESET, SELECT_DR_SCAN, SELECT_IR_SCAN, EXIT1_DR,
        EXIT1_IR, EXIT2_DR, UPDATE_DR, EXIT2_IR, UPDATE_IR: tms = 1'b1;
        default: tms = 1'b0;
    endcase
    @(negedge tck);
    if (ir_is_user) begin
        ir_is_user = !(current_state == TEST_LOGIC_RESET);
        capture_dr = (current_state == CAPTURE_DR);
        shift_dr = (current_state == SHIFT_DR);
        update_dr = (current_state == UPDATE_DR);
    end else begin
        ir_is_user = (current_state == UPDATE_IR);
        capture_dr = 1'b0;
        shift_dr = 1'b0;
        update_dr = 1'b0;
    end
    test_logic_reset = (current_state == TEST_LOGIC_RESET);
    run_test_idle = (current_state == RUN_TEST_IDLE);
    current_state = next_tap_state;
endtask

task automatic set_ir(ir_t ir);
    run_state_hw_jtag(RUN_TEST_IDLE);
    run_state_hw_jtag(SELECT_DR_SCAN);
    run_state_hw_jtag(SELECT_IR_SCAN);
    run_state_hw_jtag(CAPTURE_IR);
    for (int i = 0; i < $size(ir); i++) begin
        tdi = ir[i];
        run_state_hw_jtag(SHIFT_IR);
    end
    run_state_hw_jtag(EXIT1_IR);
    run_state_hw_jtag(UPDATE_IR);
    ir_is_user = 1'b1;
    run_state_hw_jtag(RUN_TEST_IDLE);
endtask

task automatic serialize(input string bytes_);
    int len = bytes_.len();
    $display("Serializing %d bytes", len);
    // logic [7:0] current_byte;

    run_state_hw_jtag(RUN_TEST_IDLE);
    run_state_hw_jtag(SELECT_DR_SCAN);
    run_state_hw_jtag(SELECT_IR_SCAN);
    run_state_hw_jtag(CAPTURE_DR);
    run_state_hw_jtag(SHIFT_DR);
    run_state_hw_jtag(EXIT1_DR);
    run_state_hw_jtag(UPDATE_DR);
    run_state_hw_jtag(RUN_TEST_IDLE);
endtask

string input_file = "input.txt";
string input_contents = "";
byte char = 0;

int fd, file_size;
logic [RESULT_WIDTH-1:0] result = '0;

initial begin: main_seq
    byte input_buffer [];

    // Initialize BSCANE2 Outputs

        run_state_hw_jtag(TEST_LOGIC_RESET);

    // load file contents

        if ($value$plusargs("INPUT_FILE=%s", input_file)) begin
            $display("Overriding input filename: %s", input_file);
        end else begin
            $display("Using default filename: %s", input_file);
        end
        fd = $fopen(input_file, "rb");
        if (fd==0) $fatal(2, "Failed to open file %s", input_file);
        if ($fseek(fd, 0, SEEK_END) != 0) $fatal(2, "Failed to read file %s", input_file);
        file_size = $ftell(fd);
        $display("file_size: %0d bytes", file_size);
        if ($fseek(fd, 0, SEEK_SET) != 0) $fatal(2, "Failed to read file %s", input_file);
        input_buffer = new[file_size];
        if ($fread(input_buffer, fd) != file_size) begin
                $display("Warning: Did not read expected number of bytes");
            end
        $fclose(fd);
        if (input_contents.len() != file_size)
            $fatal(1, "Failed to open file %s", input_file);
        $display("Loaded %0d bytes", file_size);

    // Upload file contents through JTAG

        set_ir(IR_USER4); // emulate setting IR to USER4 (user logic should do nothing)
        serialize(input_contents);

    // Tail

        repeat (5) run_state_hw_jtag(RUN_TEST_IDLE);



    $finish(2);
end

user_logic user_logic_i (
    // raw JTAG signals
        .tck(tck),
        .tms(tms),
        .tdi(tdi),
        .tdo(tdo),
    // TAP controller states
        .test_logic_reset(test_logic_reset),
        .ir_is_user(ir_is_user),
        .run_test_idle(run_test_idle),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
        .update_dr(update_dr));

wire _unused_ok = 1'b0 && &{1'b0,
    tdo,
    result,
    1'b0};

//`ifndef VERILATOR
initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, user_logic_tb);
end
//`endif

endmodule
`default_nettype wire
