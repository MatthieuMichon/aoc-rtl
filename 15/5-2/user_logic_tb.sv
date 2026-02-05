`timescale 1ps/1ps
`default_nettype none

module user_logic_tb;

localparam int RESULT_WIDTH = 16;

localparam int SEEK_SET = 0;
localparam int SEEK_END = 2;
localparam int FINISH_WITH_STATS = 2;

localparam int IR_LENGTH_ARM_DAP = 4;
localparam logic [IR_LENGTH_ARM_DAP-1:0] ARM_DAP_IR = 4'b0001;
localparam int IR_LENGTH_7_SERIES = 6;
localparam int IR_LENGTH = IR_LENGTH_ARM_DAP + IR_LENGTH_7_SERIES;
typedef logic [IR_LENGTH-1:0] ir_t;
localparam ir_t IR_USER4 = {ARM_DAP_IR, 6'b100011};

logic tck, tms  = 1'b1, tdi = 1'b1, tdo;
logic test_logic_reset = 1'b0, run_test_idle = 1'b0, ir_is_user = 1'b0, capture_dr = 1'b0, shift_dr = 1'b0, update_dr = 1'b0;

initial begin: tck_clock_gen
    tck = 0;
    forever #1 tck = ~tck;
end

int cycle_count = 0;

always_ff @(posedge tck) begin
    cycle_count <= cycle_count + 1;
end

typedef enum {
    TEST_LOGIC_RESET,
    RUN_TEST_IDLE,
    SELECT_DR_SCAN, SELECT_IR_SCAN,
    CAPTURE_DR, SHIFT_DR, EXIT1_DR, PAUSE_DR, EXIT2_DR, UPDATE_DR,
    CAPTURE_IR, SHIFT_IR, EXIT1_IR, PAUSE_IR, EXIT2_IR, UPDATE_IR
} state_t;

//state_t current_state = TEST_LOGIC_RESET;

task automatic run_state_hw_jtag(state_t next_tap_state);

    unique case (next_tap_state)
        TEST_LOGIC_RESET, SELECT_DR_SCAN, SELECT_IR_SCAN, EXIT1_DR,
        EXIT1_IR, EXIT2_DR, UPDATE_DR, EXIT2_IR, UPDATE_IR: tms = 1'b1;
        default: tms = 1'b0;
    endcase
    @(negedge tck);
    if (ir_is_user) begin
        ir_is_user = !(next_tap_state == TEST_LOGIC_RESET);
        capture_dr = (next_tap_state == CAPTURE_DR);
        shift_dr = (next_tap_state == SHIFT_DR);
        update_dr = (next_tap_state == UPDATE_DR);
    end else begin
        ir_is_user = (next_tap_state == UPDATE_IR);
        capture_dr = 1'b0;
        shift_dr = 1'b0;
        update_dr = 1'b0;
    end
    test_logic_reset = (next_tap_state == TEST_LOGIC_RESET);
    run_test_idle = (next_tap_state == RUN_TEST_IDLE);
    //current_state = next_tap_state;
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
    tdi = 1'b1; // go figure
    run_state_hw_jtag(EXIT1_IR);
    run_state_hw_jtag(UPDATE_IR);
    ir_is_user = 1'b1;
    repeat (10) run_state_hw_jtag(RUN_TEST_IDLE);
endtask

byte input_buffer [0:1024*1024];

task automatic serialize(input int length);

    // Change JTAG TAP state to shift-DR state

        run_state_hw_jtag(RUN_TEST_IDLE);
        run_state_hw_jtag(SELECT_DR_SCAN);
        run_state_hw_jtag(CAPTURE_DR);

    // Serialize file contents

        run_state_hw_jtag(SHIFT_DR); // ARM DAP controller in BYPASS mode
        tdi = 1'b0;

        for (int i = 0; i < length; i++) begin
            byte b = input_buffer[i];
            for (int j = 0; j < 8; j++) begin
                run_state_hw_jtag(SHIFT_DR);
                tdi = b[j];
            end
        end

    // Change JTAG TAP state to idle state

        run_state_hw_jtag(EXIT1_DR);
        run_state_hw_jtag(UPDATE_DR);
        run_state_hw_jtag(RUN_TEST_IDLE);

endtask

task automatic deserialize_non_zero(output logic [RESULT_WIDTH-1:0] result);
    result = 0;
    while (result == 0) begin: loop_null_result

        // Change JTAG TAP state to shift-DR state

            tdi = 1'b0; // replicate `scan_dr_hw_jtag $result_width -tdi 0` behavior
            run_state_hw_jtag(RUN_TEST_IDLE);
            run_state_hw_jtag(SELECT_DR_SCAN);
            run_state_hw_jtag(SELECT_IR_SCAN);
            run_state_hw_jtag(CAPTURE_DR);

        // Deserialize Contents

            for (int j=0; j<$bits(result); j++) begin
                run_state_hw_jtag(SHIFT_DR);
                result[j] = tdo;
            end
            //$display("Deserialized result: %b", result);

        // Change JTAG TAP state to idle state

        run_state_hw_jtag(EXIT1_DR);
        run_state_hw_jtag(UPDATE_DR);
        run_state_hw_jtag(RUN_TEST_IDLE);

    end
endtask

string input_file = "input.txt";

int fd, file_size, read_count;
logic [RESULT_WIDTH-1:0] result = '0;

initial begin: main_seq

    // Initialize BSCANE2 Outputs

        run_state_hw_jtag(TEST_LOGIC_RESET);
        repeat (10) run_state_hw_jtag(RUN_TEST_IDLE);

    // load file contents

        if ($value$plusargs("INPUT_FILE=%s", input_file)) begin
            $display("Overriding input filename: %s", input_file);
        end else begin
            $display("Using default filename: %s", input_file);
        end
        fd = $fopen(input_file, "rb");
        if (fd == 0) begin
            $fatal(FINISH_WITH_STATS, "Failed to open file %s", input_file);
        end
        if ($fseek(fd, 0, SEEK_END) != 0) begin
            $fatal(FINISH_WITH_STATS, "Failed to read file %s", input_file);
        end
        file_size = $ftell(fd);
        $display("file_size: %0d bytes", file_size);
        if ($fseek(fd, 0, SEEK_SET) != 0) begin
            $fatal(FINISH_WITH_STATS, "Failed to read file %s", input_file);
        end
        read_count = $fread(input_buffer, fd, 0, file_size);
        $fclose(fd);
        if (read_count != file_size) begin
            $fatal(FINISH_WITH_STATS, "Failed to read file %s", input_file);
        end
        $display("Loaded %0d bytes", file_size);

    // Upload file contents through JTAG and readback results

        set_ir(IR_USER4); // emulate setting IR to USER4 (user logic should do nothing)
        serialize(file_size);
        $display("Transferred %0d bytes", file_size);
        deserialize_non_zero(result);
        $display("Result: %0d (0x%h)", result, result);

    // Tail

        repeat (5) run_state_hw_jtag(RUN_TEST_IDLE);
        $display("Finished after %0d cycles", cycle_count);
        $finish(FINISH_WITH_STATS);
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
    read_count,
    FINISH_WITH_STATS,
    input_buffer[0],
    1'b0};

//`ifndef VERILATOR
initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, user_logic_tb);
end
//`endif

endmodule
`default_nettype wire
