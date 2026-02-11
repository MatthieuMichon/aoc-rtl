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

logic last, valid;
operation_t operation;
position_t start_row, start_col, end_row, end_col;
position_t row_count;

assign {last, valid, operation, start_row, start_col, end_row, end_col} = instr_data;

always @(posedge clk) begin: row_check
    assert (!(instr_ready && instr_valid && (start_row > end_row)))
        else $error("Unexpected start_row vs end_row");
end

always_ff @(posedge clk) begin: dummy_flow_control
    if (reset) begin
        instr_ready <= 1'b0;
        row_count <= '0;
    end else begin
        if (instr_ready && instr_valid) begin
            instr_ready <= 1'b0;
            row_count <= end_row - start_row;
        end else if (row_count > 0) begin
            row_count <= row_count - 1;
        end else begin
            instr_ready <= 1'b1;
        end
    end
end

per_ram_t array_we;
logic [RAM_INSTANCES*RAM_DATA_WIDTH-1:0] array_wdata, array_rdata;
lit_count_per_ram_t [RAM_INSTANCES-1:0] array_lit_count;
lit_count_t lit_count;

always_ff @(posedge clk) begin
    if (reset) begin
        array_we <= '0;
        array_wdata <= '0;
    end else begin
        for (int i = 0; i < RAM_INSTANCES; i++) begin
            if ((i >= int'(start_col)/RAM_INSTANCES) && (i <= int'(end_col)/RAM_INSTANCES)) begin
                array_we[i] <= (row_count > 0);
                if (operation == TURN_OFF) begin
                    array_wdata[RAM_DATA_WIDTH*i+:RAM_DATA_WIDTH] <= '0;
                end else if (operation == TURN_ON) begin
                    array_wdata[RAM_DATA_WIDTH*i+:RAM_DATA_WIDTH] <= '1;
                end
            end else begin
                array_we[i] <= 1'b0;
            end
        end
    end
end

ram_addr_t lit_count_addr;

genvar i;
generate
    for (i = 0; i < RAM_INSTANCES; i++) begin

        ram_data_t ram_read_out;

        light_display_ram #(
            .ADDR_WIDTH(RAM_ADDR_WIDTH),
            .DATA_WIDTH(RAM_DATA_WIDTH)
        ) light_display_ram_i (
            .clk(clk),
            // Port A: R/W light state update
            .wea(array_we[i]),
            .addra(RAM_ADDR_WIDTH'(row_count)), // strip extra bits (only for QoL)
            .dia(array_wdata[RAM_DATA_WIDTH*i+:RAM_DATA_WIDTH]),
            .doa(array_rdata[RAM_DATA_WIDTH*i+:RAM_DATA_WIDTH]),
            // Port B: RO final lit lights count
            .addrb(RAM_ADDR_WIDTH'(lit_count_addr)), // strip extra bits (only for QoL)
            .dob(ram_read_out)
        );

        always_ff @(posedge clk) array_lit_count[i] <= $countones(ram_read_out);

    end
endgenerate

always_ff @(posedge clk) begin
    if (reset) begin
        lit_count_addr <= '0;
    end else begin
        lit_count_addr <= lit_count_addr + 1'b1;
    end
end

always_comb begin
    lit_count = '0;
    for (int j = 0; j < RAM_INSTANCES; j++) begin
        lit_count = lit_count + LIT_COUNT'(array_lit_count[j]);
    end
end

always_ff @(posedge clk) begin: finish_condition
    if (reset) begin
        count_done <= 1'b0;
        count_value <= '0;
    end else begin
        if (instr_ready && instr_valid) begin
            count_done <= instr_last;
            count_value <= RESULT_WIDTH'(lit_count);
        end
    end
end

wire _unused_ok = 1'b0 && &{1'b0,
    last, valid, operation, start_col, end_col,
    array_rdata,
    1'b0};

endmodule
`default_nettype wire
