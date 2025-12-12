`timescale 1ps/1ps
`default_nettype none

module user_logic_tb;



logic tck, tdi, tdo;
logic test_logic_reset, run_test_idle, ir_is_user, capture_dr, shift_dr, update_dr;

initial begin
    tck = 0;
    forever #1 tck = ~tck;
end

localparam int IR_LENGTH = 6;

typedef enum {
    TEST_LOGIC_RESET,
    RUN_TEST_IDLE,
    SELECT_DR_SCAN,
    CAPTURE_DR,
    SHIFT_DR,
    EXIT1_DR,
    PAUSE_DR,
    EXIT2_DR,
    UPDATE_DR,
    IR
} state_t;

task automatic run_state_hw_jtag(state_t tap_state);
    unique case (tap_state)
        TEST_LOGIC_RESET: begin
            test_logic_reset = 1'b1;
            run_test_idle = 1'b0;
            capture_dr = 1'b0;
            shift_dr = 1'b0;
            update_dr = 1'b0;
        end
        RUN_TEST_IDLE: begin
            test_logic_reset = 1'b0;
            run_test_idle = 1'b1;
            capture_dr = 1'b0;
            shift_dr = 1'b0;
            update_dr = 1'b0;
        end
        SELECT_DR_SCAN: begin
            test_logic_reset = 1'b0;
            run_test_idle = 1'b0;
            capture_dr = 1'b0;
            shift_dr = 1'b0;
            update_dr = 1'b0;
        end
        CAPTURE_DR: begin
            test_logic_reset = 1'b0;
            run_test_idle = 1'b0;
            capture_dr = 1'b1;
            shift_dr = 1'b0;
            update_dr = 1'b0;
        end
        SHIFT_DR: begin
            test_logic_reset = 1'b0;
            run_test_idle = 1'b0;
            capture_dr = 1'b0;
            shift_dr = 1'b1;
            update_dr = 1'b0;
        end
        EXIT1_DR: begin
            test_logic_reset = 1'b0;
            run_test_idle = 1'b0;
            capture_dr = 1'b0;
            shift_dr = 1'b0;
            update_dr = 1'b0;
        end
        PAUSE_DR: begin
            test_logic_reset = 1'b0;
            run_test_idle = 1'b0;
            capture_dr = 1'b0;
            shift_dr = 1'b0;
            update_dr = 1'b0;
        end
        EXIT2_DR: begin
            test_logic_reset = 1'b0;
            run_test_idle = 1'b0;
            capture_dr = 1'b0;
            shift_dr = 1'b0;
            update_dr = 1'b0;
        end
        UPDATE_DR: begin
            test_logic_reset = 1'b0;
            run_test_idle = 1'b0;
            capture_dr = 1'b0;
            shift_dr = 1'b0;
            update_dr = 1'b1;
        end
        IR: begin
            test_logic_reset = 1'b0;
            run_test_idle = 1'b0;
            capture_dr = 1'b0;
            shift_dr = 1'b0;
            update_dr = 1'b0;
        end
    endcase
endtask

task automatic serialize(input string bytes_);
    int num_bytes = bytes_.len();
    int deci = num_bytes / 10;
    byte char;
    for (int i=0; i<num_bytes; i++) begin
        if (i % deci == 0)
            $display("Processed %d %%", 100*i/num_bytes);
        run_state_hw_jtag(RUN_TEST_IDLE);
        @(posedge tck);
        run_state_hw_jtag(SELECT_DR_SCAN);
        @(posedge tck);
        run_state_hw_jtag(CAPTURE_DR);
        @(posedge tck);
        run_state_hw_jtag(SHIFT_DR);
        char = bytes_[i];
        for (int j=0; j<8; j++) begin
            tdi = char[j];
            @(posedge tck); // commit bit shift
        end
        run_state_hw_jtag(EXIT1_DR);
        @(posedge tck);
        run_state_hw_jtag(UPDATE_DR);
        @(posedge tck);
    end
    run_state_hw_jtag(RUN_TEST_IDLE);
    @(posedge tck);
endtask

localparam int RESULT_WIDTH = 16;
localparam int SEEK_SET = 0;
localparam int SEEK_END = 2;

task automatic deserialize(output logic [RESULT_WIDTH-1:0] result);
    run_state_hw_jtag(SELECT_DR_SCAN);
    @(posedge tck);
    run_state_hw_jtag(CAPTURE_DR);
    @(posedge tck);
    run_state_hw_jtag(SHIFT_DR);

    tdi = 1'b0; // replicate TCL script behavior
    for (int j=0; j<$bits(result); j++) begin
        result[j]= tdo;
        @(posedge tck); // commit bit shift
    end

    run_state_hw_jtag(EXIT1_DR);
    @(posedge tck);
    run_state_hw_jtag(UPDATE_DR);
    @(posedge tck);
    run_state_hw_jtag(RUN_TEST_IDLE);
    @(posedge tck);
endtask

string input_file = "input.txt";
string input_contents = "";

initial begin
    int fd, file_size;
    byte char;
    logic [RESULT_WIDTH-1:0] result;

    // set initial values

        ir_is_user = 1'b0;
        run_state_hw_jtag(TEST_LOGIC_RESET);
        @(posedge tck);
        tdi = 1'b0; // whatever value
        run_state_hw_jtag(RUN_TEST_IDLE);
        @(posedge tck);

    // set instruction register to `USER4`

        run_state_hw_jtag(SELECT_DR_SCAN);
        @(posedge tck);
        run_state_hw_jtag(IR); // SELECT_IR_SCAN
        @(posedge tck);
        run_state_hw_jtag(IR); // CAPTURE_IR
        @(posedge tck);
        for (int j=0; j<IR_LENGTH; j++) begin
            run_state_hw_jtag(IR); // SHIFT_IR
            @(posedge tck);
        end
        run_state_hw_jtag(IR); // EXIT1_IR
        @(posedge tck);
        run_state_hw_jtag(IR); // UPDATE_IR
        @(posedge tck);
        ir_is_user = 1'b1;
        run_state_hw_jtag(RUN_TEST_IDLE);
        @(posedge tck);

    // load file contents

        if ($value$plusargs("INPUT_FILE=%s", input_file)) begin
            $display("Overriding input filename: %s", input_file);
        end else begin
            $display("Using default filename: %s", input_file);
        end
        fd = $fopen(input_file, "r");
        if (fd==0) $fatal(1, "Failed to open file %s", input_file);
        $fseek(fd, 0, SEEK_END);
        file_size = $ftell(fd);
        $display("file_size: %d bytes", file_size);
        $fseek(fd, 0, SEEK_SET);
        while (1) begin
            char = $fgetc(fd);
            if (char == -1)
                break;
            input_contents = $sformatf("%s%c", input_contents, char);
        end
        $fclose(fd);
        if (input_contents.len() != file_size)
            $fatal(1, "Failed to open file %s", input_file);
        $display("Loaded %d bytes", file_size);

    // set instruction register to `USER4`

        ir_is_user = 1'b1;
        @(posedge tck); // transition to state `run-test/idle`

    // serialize rotation commands and readback result

        serialize(input_contents);
        repeat(250) @(posedge tck); // account for pipeline stages by cycling tck
        deserialize(result);
        $display("Result: %d (0x%h)", result, result);

    $finish;
end

user_logic user_logic_i (
    // BSCAN signals
        .tck(tck),
        .tdi(tdi),
        .tdo(tdo),
        .test_logic_reset(test_logic_reset),
        .run_test_idle(run_test_idle),
        .ir_is_user(ir_is_user),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
        .update_dr(update_dr));

endmodule
`default_nettype wire
