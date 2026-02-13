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

localparam int OPERATION_WIDTH = 2;
localparam int POSITION_WIDTH = 12;
localparam int ROWS = 1000;
localparam int COLS = 1000;
localparam int RAM_ADDR_WIDTH = $clog2(ROWS);
localparam int RAM_DATA_WIDTH = 32;
localparam int RAM_INSTANCES = (COLS + RAM_DATA_WIDTH - 1) / RAM_DATA_WIDTH; // 1000 -> 32 x 32
localparam int LIT_COUNT_PER_RAM_WIDTH = $clog2(RAM_DATA_WIDTH+1);
localparam int LIT_COUNT = $clog2(ROWS*COLS);
localparam int LIT_COUNT_READ_LATENCY = 2; // DPRAM + $countones

typedef logic [INSTRUCTION_WIDTH-1:0] instruction_t;
typedef logic [OPERATION_WIDTH-1:0] operation_t;
typedef logic [POSITION_WIDTH-1:0] position_t;
typedef enum operation_t {
    TURN_OFF = 2'b00,
    TOGGLE = 2'b01,
    TURN_ON = 2'b11
} operations_t;
typedef logic [RAM_ADDR_WIDTH-1:0] ram_addr_t;
typedef logic [RAM_DATA_WIDTH-1:0] ram_data_t;
typedef logic [RAM_INSTANCES-1:0] per_ram_t;
typedef logic [LIT_COUNT_PER_RAM_WIDTH-1:0] lit_count_per_ram_t;
typedef logic [LIT_COUNT-1:0] lit_count_t;

logic start_process;
logic last, valid;
operation_t operation;
position_t start_row, start_col, end_row, end_col;
logic readback_pending, update_ram_data;
logic current_op_is_last, finished_last_op;
logic lit_count_read_enable;
logic lit_count_done;
lit_count_t comb_lit_count;
logic [LIT_COUNT_READ_LATENCY-1:0] lit_count_read_delay;
lit_count_per_ram_t [RAM_INSTANCES-1:0] array_lit_count;
lit_count_t lit_count;
ram_addr_t ram_addra, ram_addrb, ram_addrb_readback, ram_addrb_readback_reg, ram_addrb_lit_count;

always_ff @(posedge clk) begin: manage_flow_control
    if (reset) begin
        instr_ready <= 1'b0;
        start_process <= 1'b0;
        operation <= TURN_OFF;
        start_row <= '0;
        start_col <= '0;
        end_row <= '0;
        end_col <= '0;
    end else begin
        start_process <= 1'b0;
        if (instr_ready && instr_valid) begin: valid_transaction
            instr_ready <= 1'b0;
            start_process <= 1'b1;
            {last, valid, operation, start_row, start_col, end_row, end_col} <= instr_data;
        end else if (!readback_pending && !start_process) begin: downstream_ready
            instr_ready <= 1'b1;
        end
    end
end

always_ff @(posedge clk) begin: process_instruction
    if (reset) begin
        ram_addra <= '0;
        ram_addrb_readback <= '0;
        ram_addrb_readback_reg <= '0;
        readback_pending <= 1'b0;
        update_ram_data <= 1'b0;
    end else begin
        if (start_process) begin: valid_transaction
            readback_pending <= 1'b1;
            ram_addrb_readback <= RAM_ADDR_WIDTH'(start_row);
        end else begin
            if (ram_addrb_readback >= RAM_ADDR_WIDTH'(end_row)) begin
                readback_pending <= 1'b0;
            end else begin
                ram_addrb_readback <= ram_addrb_readback + 1'b1;
            end
        end
        ram_addra <= ram_addrb_readback_reg;
        ram_addrb_readback_reg <= ram_addrb_readback;
        update_ram_data <= readback_pending;
    end
end

assign lit_count_read_enable = finished_last_op && !(&ram_addrb_lit_count);

always_ff @(posedge clk) begin: latch_last_flag
    if (reset) begin
        current_op_is_last <= 1'b0;
        finished_last_op <= 1'b0;
    end else if (!current_op_is_last && instr_ready && instr_valid && instr_last) begin
        current_op_is_last <= 1'b1;
    end else if (current_op_is_last && instr_ready) begin: finish_last_operation
        finished_last_op <= 1'b1;
    end
end

// Shared port B
assign ram_addrb = lit_count_read_enable ? ram_addrb_lit_count : ram_addrb_readback;

genvar i;
generate
    for (i = 0; i < RAM_INSTANCES; i++) begin

        localparam int LSB_INDEX = i * RAM_DATA_WIDTH;
        localparam int MSB_INDEX = LSB_INDEX + RAM_DATA_WIDTH - 1;

        logic ram_wea;
        ram_data_t data_mask;
        ram_data_t ram_dia, ram_doa, ram_dob;

        always_comb begin: compute_mask
            data_mask = '0;
            for (integer j = LSB_INDEX; j <= MSB_INDEX; j = j + 1) begin
                data_mask[j - LSB_INDEX] = (j >= start_col) && (j <= end_col);
            end
        end

        always_ff @(posedge clk) begin: execute_operation
            if (reset) begin
                ram_wea <= '0;
                ram_dia <= '0;
            end else begin
                ram_wea <= update_ram_data & (|data_mask);
                unique case (operation)
                    TURN_OFF: ram_dia <= ram_dob & ~data_mask;
                    TOGGLE: ram_dia <= ram_dob ^ data_mask;
                    TURN_ON: ram_dia <= ram_dob | data_mask;
                    default: ram_dia <= ram_dob;
                endcase
            end
        end

        light_display_ram #(
            .ADDR_WIDTH(RAM_ADDR_WIDTH),
            .DATA_WIDTH(RAM_DATA_WIDTH)
        ) light_display_ram_i (
            .clk(clk),
            // Port A: R/W light state update
            .wea(ram_wea),
            .addra(ram_addra),
            .dia(ram_dia),
            .doa(ram_doa),
            // Port B: RO final lit lights count
            .addrb(ram_addrb),
            .dob(ram_dob)
        );

        always_ff @(posedge clk) array_lit_count[i] <= $countones(ram_dob);

        wire _unused_ok_1 = 1'b0 && &{1'b0,
            ram_doa,
            1'b0};

    end
endgenerate

always_comb begin: count_lit_lights
    comb_lit_count = '0;
    for (integer j = 0; j < RAM_INSTANCES; j = j + 1) begin
        comb_lit_count = comb_lit_count + LIT_COUNT'(array_lit_count[j]);
    end
end

always_ff @(posedge clk) begin: lit_lights_count_addr_gen
    if (reset) begin
        ram_addrb_lit_count <= '0;
        lit_count_done <= 1'b0;
    end else if (finished_last_op) begin
        if (!(&ram_addrb_lit_count)) begin
            ram_addrb_lit_count <= ram_addrb_lit_count + 1'b1;
        end else begin
            lit_count_done <= 1'b1;
        end
    end
end

always_ff @(posedge clk) begin
    if (reset) begin
        lit_count <= '0;
    end else begin
        if (lit_count_read_delay[LIT_COUNT_READ_LATENCY-1]) begin
            lit_count <= lit_count + comb_lit_count;
        end
        lit_count_read_delay <= {lit_count_read_delay[LIT_COUNT_READ_LATENCY-2:0], lit_count_read_enable};
    end
end

always_ff @(posedge clk) begin: finish_condition
    if (reset) begin
        count_done <= 1'b0;
        count_value <= '0;
    end else begin
        if (lit_count_done) begin
            count_done <= 1'b1;
            count_value <= RESULT_WIDTH'(lit_count);
        end
    end
end

wire _unused_ok = 1'b0 && &{1'b0,
    last, valid, start_row, start_col, start_col, end_row, end_col,
    readback_pending,
    1'b0};

endmodule
`default_nettype wire
