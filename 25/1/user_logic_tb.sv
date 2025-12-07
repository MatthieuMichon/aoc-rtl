`timescale 1ps/1ps
`default_nettype none

module user_logic_tb;

string input_file = "input.txt";

localparam time TCK_PERIOD = 10ps;
initial begin
    tck = 0;
    forever #(TCK_PERIOD/2) tck = ~tck;
end

/* Example from the problem statement:
    ```
    L68
    L30
    R48
    L5
    R60
    L55
    L1
    L99
    R14
    L82
    ```
*/
//localparam string ROTATIONS_STR = "L68\nL30\nR48\nL5\nR60\nL55\nL1\nL99\nR14\nL82\n";

logic tck, tdi, tdo;
logic test_logic_reset, ir_is_user, capture_dr, shift_dr, update_dr;

task automatic serialize(input string bytes_);

    int num_bytes = bytes_.len();
    byte char;

    for (int i=0; i<num_bytes; i++) begin

        if (i % 1000 == 0)
            $display("Processing byte %0d of %0d", i, num_bytes);

        // transition from `run-test/idle` to `capture-DR`

            test_logic_reset = 1'b0;
            capture_dr = 1'b0;
            shift_dr = 1'b0;
            update_dr = 1'b0;
            @(posedge tck); // `run-test/idle`
            test_logic_reset = 1'b0;
            capture_dr = 1'b0;
            shift_dr = 1'b0;
            update_dr = 1'b0;
            @(posedge tck); // `select-DR-scan`
            test_logic_reset = 1'b0;
            capture_dr = 1'b1; // set bit
            shift_dr = 1'b0;
            update_dr = 1'b0;
            @(posedge tck); // `capture-DR`

        // transition to `shift-DR`

            test_logic_reset = 1'b0;
            capture_dr = 1'b0;
            shift_dr = 1'b1; // set bit
            update_dr = 1'b0;

        // shift eight bits

            char = bytes_[i];
            for (int j=0; j<8; j++) begin
                tdi = char[j];
                @(posedge tck); // commit bit shift
            end

        // transition to `update-DR`

            test_logic_reset = 1'b0;
            capture_dr = 1'b0;
            shift_dr = 1'b0;
            update_dr = 1'b0;
            @(posedge tck); // `exit-DR`
            test_logic_reset = 1'b0;
            capture_dr = 1'b0;
            shift_dr = 1'b0;
            update_dr = 1'b1; // set bit
            @(posedge tck); // `update-DR`

    end

    // transition to `run-test/idle`

        test_logic_reset = 1'b0;
        capture_dr = 1'b0;
        shift_dr = 1'b0;
        update_dr = 1'b0;
        @(posedge tck); // `run-test/idle`

endtask

task automatic deserialize_password(output logic [16-1:0] password);

    // transition from `run-test/idle` to `capture-DR`

        test_logic_reset = 1'b0;
        capture_dr = 1'b0;
        shift_dr = 1'b0;
        update_dr = 1'b0;
        @(posedge tck); // `select-DR-scan`
        test_logic_reset = 1'b0;
        capture_dr = 1'b1; // set bit
        shift_dr = 1'b0;
        update_dr = 1'b0;
        @(posedge tck); // `capture-DR`

    // transition to `shift-DR`

        test_logic_reset = 1'b0;
        capture_dr = 1'b0;
        shift_dr = 1'b1; // set bit
        update_dr = 1'b0;

    // shift 16 bits

        tdi = 1'b0; // replicate TCL script behavior
        for (int j=0; j<16; j++) begin
            password[j]= tdo;
            @(posedge tck); // commit bit shift
        end

    // transition to `update-DR`

        test_logic_reset = 1'b0;
        capture_dr = 1'b0;
        shift_dr = 1'b0;
        update_dr = 1'b0;
        @(posedge tck); // `exit-DR`
        test_logic_reset = 1'b0;
        capture_dr = 1'b0;
        shift_dr = 1'b0;
        update_dr = 1'b1; // set bit
        @(posedge tck); // `update-DR`

    // transition to `run-test/idle`

        test_logic_reset = 1'b0;
        capture_dr = 1'b0;
        shift_dr = 1'b0;
        update_dr = 1'b0;
        @(posedge tck); // `run-test/idle`

endtask

localparam int ZYNQ7_IR_LENGTH = 10;
localparam int SEEK_SET = 0;
localparam int SEEK_END = 2;

string rotations = "";

initial begin
    logic [16-1:0] password;
    int fd, file_size;
    int char;

    if ($value$plusargs("INPUT_FILE=%s", input_file)) begin
        $display("Overriding input filename: %s", input_file);
    end else begin
        $display("Using default filename: %s", input_file);
    end

    // load file contents

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
            rotations = $sformatf("%s%c", rotations, char);
        end
        $fclose(fd);
        if (rotations.len() != file_size)
            $fatal(1, "Failed to open file %s", input_file);
        $display("Loaded %d bytes", file_size);

    // start with TAP state in `test-logic-reset`

        test_logic_reset = 1'b1;
        capture_dr = 1'b0;
        shift_dr = 1'b0;
        update_dr = 1'b0;
        // instruction register is set to `bypass` in state `test-logic-reset`
        ir_is_user = 1'b0;
        tdi = 1'b0; // whatever value
        repeat(42) @(posedge tck); // may as well wait 42 because why not

    // transition out of `test-logic-reset`

        test_logic_reset = 1'b0;
        capture_dr = 1'b0;
        shift_dr = 1'b0;
        update_dr = 1'b0;
        ir_is_user = 1'b0;
        repeat(5+ZYNQ7_IR_LENGTH) @(posedge tck); // five transitions for reaching state `shift-IR`

    // set instruction register to `USER4`

        test_logic_reset = 1'b0;
        capture_dr = 1'b0;
        shift_dr = 1'b0;
        update_dr = 1'b0;
        ir_is_user = 1'b0;
        repeat(5) @(posedge tck); // five transitions for reaching state `shift-IR`
        repeat(ZYNQ7_IR_LENGTH) @(posedge tck); // shift `USER4` JTAG instruction bits
        repeat(2) @(posedge tck); // two transitions for reaching state `update-IR`
        ir_is_user = 1'b1;
        @(posedge tck); // transition to state `run-test/idle`

    // serialize rotation commands and readback password

        serialize(rotations);
        repeat(10) @(posedge tck); // account for pipeline stages by cycling tck
        deserialize_password(password);
        $display("Password readback: %d (0x%h)", password, password);

    $finish;
end

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
