`timescale 1ns/1ps
`default_nettype none

module light_display #(
    parameter int INSTRUCTION_WIDTH,
    parameter int RESULT_WIDTH
)(
    input wire clk,
    input wire reset,
    // Instruction Data
        input wire instr_last,
        output logic instr_ready,
        input wire instr_valid,
        input wire [INSTRUCTION_WIDTH-1:0] instr_data,
    // Final Lit Lights
        output logic count_done,
        output logic [RESULT_WIDTH-1:0] count_value
);

localparam int OPERATION_BITS = 2;
localparam int POSITION_BITS = 12;
localparam int COMMAND_BITS = OPERATION_BITS+4*POSITION_BITS;
localparam int LIGHT_UPDATE_LATENCY = 3;
localparam int ROWS = 1000;
localparam int COLS = 1000;
localparam int RD_PTR = 0;
localparam int WR_PTR = LIGHT_UPDATE_LATENCY-1;
localparam int RAM_ADDR_WIDTH = $clog2(ROWS);
localparam int RAM_DATA_WIDTH = 36;
localparam int COLS_PER_RAM = 6;
localparam int RAM_INSTANCES = int'($ceil(1.0*COLS/COLS_PER_RAM));
localparam int COL_DATA_WIDTH = RAM_DATA_WIDTH/COLS_PER_RAM;
localparam int COL_ACC_WIDTH = $clog2(ROWS)+COL_DATA_WIDTH;
localparam int RAM_ACC_WIDTH = $clog2(COLS_PER_RAM)+COL_ACC_WIDTH;
localparam int ACC_WIDTH = $clog2(RAM_INSTANCES)+RAM_ACC_WIDTH;

typedef logic [OPERATION_BITS-1:0] operation_t;
typedef logic [POSITION_BITS-1:0] postion_t;
typedef logic [COMMAND_BITS-1:0] raw_cmd_t;
typedef logic [POSITION_BITS-1:0] ptr_t;
typedef logic [RAM_DATA_WIDTH-1:0] ram_data_t;
typedef logic [COL_DATA_WIDTH-1:0] col_data_t;
typedef logic [COL_ACC_WIDTH-1:0] col_acc_t;
typedef logic [RAM_ACC_WIDTH-1:0] ram_acc_t;
typedef logic [ACC_WIDTH-1:0] acc_t;

typedef enum operation_t {
    TURN_OFF = 2'b00,
    TOGGLE = 2'b01,
    RESERVED = 2'b10,
    TURN_ON = 2'b11
} op_e;
typedef struct packed {
    op_e op;
    postion_t start_row, start_col;
    postion_t end_row, end_col;
} cmd_s;
typedef union packed {
    cmd_s f;
    //raw_cmd_t raw;
} cmd_u;

typedef enum logic [3-1:0] {
    SM_WAIT_RESET_FALLING,
    SM_ASSERT_READY,
    SM_CAPTURE_CMD,
    SM_WAIT_CMD_PROCESSED,
    SM_START_INTENSITY_SUM,
    SM_WAIT_INTENSITY_SUM,
    SM_FINISHED
} sm_states_e;

sm_states_e curr_state, next_state;
logic cmd_processed, last_cmd, sum_completed;
cmd_u captured_cmd;
logic [LIGHT_UPDATE_LATENCY-1:0] we_sr;
ptr_t [LIGHT_UPDATE_LATENCY-1:0] row_ptr;
acc_t [RAM_INSTANCES:0] acc_array;

always_ff @(posedge clk) begin: current_state_update
    if (reset) begin
        curr_state <= SM_WAIT_RESET_FALLING;
    end else begin
        curr_state <= next_state;
    end
end

always_comb begin: next_state_logic
    unique case (curr_state)
        SM_WAIT_RESET_FALLING: begin
            if (reset) begin: reset_still_asserted
                next_state = SM_WAIT_RESET_FALLING;
            end else begin
                next_state = SM_ASSERT_READY;
            end
        end
        SM_ASSERT_READY: begin
            if (!(instr_ready && instr_valid)) begin: wait_transaction
                next_state = SM_ASSERT_READY;
            end else begin
                next_state = SM_CAPTURE_CMD;
            end
        end
        SM_CAPTURE_CMD: begin
            next_state = SM_WAIT_CMD_PROCESSED;
        end
        SM_WAIT_CMD_PROCESSED: begin
            if (!cmd_processed) begin
                next_state = SM_WAIT_CMD_PROCESSED;
            end else if (!last_cmd) begin
                next_state = SM_ASSERT_READY;
            end else begin
                next_state = SM_START_INTENSITY_SUM;
            end
        end
        SM_START_INTENSITY_SUM: begin
            next_state = SM_WAIT_INTENSITY_SUM;
        end
        SM_WAIT_INTENSITY_SUM: begin
            if (!sum_completed) begin
                next_state = SM_WAIT_INTENSITY_SUM;
            end else begin
                next_state = SM_FINISHED;
            end
        end
        default: next_state = SM_FINISHED;
    endcase
end

always_ff @(posedge clk) begin: manage_backpressure
    if (reset) begin
        instr_ready <= 1'b0;
        captured_cmd <= '0;
    end else begin
        instr_ready <= 1'b0;
        unique case (curr_state)
            SM_ASSERT_READY: begin
                instr_ready <= 1'b1;
                captured_cmd <= COMMAND_BITS'(instr_data);
            end
        default: begin end
        endcase
    end
end

always_ff @(posedge clk) begin: track_last_cmd
    if (reset) begin
        last_cmd <= 1'b0;
    end else if (instr_last && instr_ready && instr_valid) begin
        last_cmd <= 1'b1;
    end
end

always_ff @(posedge clk) begin: update_row_ptr
    if (reset) begin
        cmd_processed <= 1'b0;
        we_sr <= '0;
        row_ptr <= '0;
    end else begin
        cmd_processed <= 1'b0;
        we_sr <= {we_sr[$size(we_sr)-2:0], 1'b0};
        unique case (curr_state)
            SM_CAPTURE_CMD: begin
                we_sr[RD_PTR] <= 1'b1;
                row_ptr[RD_PTR] <= captured_cmd.f.start_row;
            end
            SM_WAIT_CMD_PROCESSED: begin
                cmd_processed <= (row_ptr[WR_PTR] >= captured_cmd.f.end_row);
                we_sr <= {we_sr[$size(we_sr)-2:0], (row_ptr[RD_PTR] < captured_cmd.f.end_row)};
                row_ptr <= {row_ptr[$size(row_ptr)-2:0], row_ptr[RD_PTR]+1'b1};
            end
            SM_START_INTENSITY_SUM: begin
                row_ptr[RD_PTR] <= '0;
            end
            SM_WAIT_INTENSITY_SUM: begin
                sum_completed <= (int'(row_ptr[RD_PTR]) > ROWS + LIGHT_UPDATE_LATENCY);
                row_ptr[RD_PTR] <= row_ptr[RD_PTR] + 1'b1;
            end
            default: begin end
        endcase
    end
end

always_ff @(posedge clk) acc_array[0] <= '0;

genvar i, j; generate
for (i=0; i<RAM_INSTANCES; i++) begin: per_ram

    ram_data_t ram_rd_data, ram_wr_data;
    col_acc_t [COLS_PER_RAM-1:0] per_col_acc;
    ram_acc_t comb_per_ram_acc;

    light_display_ram #(
        .ADDR_WIDTH(RAM_ADDR_WIDTH),
        .DATA_WIDTH(RAM_DATA_WIDTH)
    ) light_display_ram_i (
        .clk,
        // Port A: read-only
            .addra(RAM_ADDR_WIDTH'(row_ptr[RD_PTR])),
            .doa(ram_rd_data),
        // Port B: write-only
            .web(we_sr[WR_PTR]),
            .addrb(RAM_ADDR_WIDTH'(row_ptr[WR_PTR])),
            .dib(ram_wr_data)
    );

    for (j=0; j<COLS_PER_RAM; j++) begin: per_col_per_ram

        localparam int COL_INDEX = i*COLS_PER_RAM+j;

        col_data_t col_rd_data, col_wr_data;

        function automatic logic is_col_selected(cmd_u cmd, int index);
            is_col_selected =
                    (int'(cmd.f.start_col) <= index) &&
                    (index <= int'(cmd.f.end_col));
        endfunction

        assign col_rd_data = ram_rd_data[j*COL_DATA_WIDTH+:COL_DATA_WIDTH];
        assign ram_wr_data[j*COL_DATA_WIDTH+:COL_DATA_WIDTH] = col_wr_data;

        always_ff @(posedge clk) begin: execute_op
            if (is_col_selected(captured_cmd, COL_INDEX)) begin
                unique case (captured_cmd.f.op)
                    TURN_OFF: begin
                        col_wr_data <= (|col_rd_data) ? (col_rd_data - 1'b1) : col_rd_data;
                    end
                    TOGGLE: begin
                        col_wr_data <= col_rd_data + COL_DATA_WIDTH'(1);
                    end
                    RESERVED: begin
                        col_wr_data <= col_rd_data;
                    end
                    TURN_ON: begin
                        col_wr_data <= col_rd_data + COL_DATA_WIDTH'(1);
                    end
                endcase
            end
        end

        always_ff @(posedge clk) begin
            if (reset) begin
                per_col_acc[j] <= 0;
            end else if (last_cmd && !sum_completed) begin
                per_col_acc[j] <= per_col_acc[j] + COL_ACC_WIDTH'(col_rd_data);
            end
        end

    end

    always_comb begin
        comb_per_ram_acc = '0;
        for (int k=0; k<COLS_PER_RAM; k++) begin
            comb_per_ram_acc = comb_per_ram_acc + (COL_ACC_WIDTH+3)'(per_col_acc[k]);
        end
    end

    always_ff @(posedge clk) begin
        acc_array[1+i] <= acc_array[i] + ACC_WIDTH'(comb_per_ram_acc);
    end

    wire _unused_ok = 1'b0 && &{1'b0,
        1'b0};

end
endgenerate;

assign count_done = sum_completed;
assign count_value = 24'(acc_array[RAM_INSTANCES]);

wire _unused_ok = 1'b0 && &{1'b0,
    instr_last,
    instr_data,
    count_done,
    count_value,
    we_sr,
    1'b0};

endmodule
`default_nettype wire
