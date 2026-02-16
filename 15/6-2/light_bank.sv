`timescale 1ns/1ps
`default_nettype none

module light_bank #(
    parameter int CMD_DATA_WIDTH,
    parameter int INTENSITY_WIDTH,
    parameter int START_LIGHT_INDEX,
    parameter int STOP_LIGHT_INDEX
)(
    input wire clk,
    input wire reset,
    // Instruction Data
        input wire cmd_last,
        output logic cmd_ready,
        input wire cmd_valid,
        input wire [CMD_DATA_WIDTH-1:0] cmd_data,
    // Intensity Total
        input wire cascade_in_valid,
        input wire [INTENSITY_WIDTH-1:0] cascade_in_intensity,
        output logic cascade_out_valid,
        output logic [INTENSITY_WIDTH-1:0] cascade_out_intensity
);

localparam int OPERATION_WIDTH = 2;
localparam int POSITION_WIDTH = 12;
localparam int ROWS = 1000;

typedef logic [OPERATION_WIDTH-1:0] op_t;
typedef logic [POSITION_WIDTH-1:0] pos_t;
typedef logic [POSITION_WIDTH-1:0] ptr_t;

typedef struct packed {
    op_t operation;
    pos_t start_row, start_col;
    pos_t end_row, end_col;
} cmd_fields_t;

typedef union packed {
    cmd_fields_t map;
} cmd_t;

cmd_t cmd_data_i, cmd_data_reg;
logic cmd_pending, received_last_cmd, no_more_cmd;
ptr_t ram_rd_ptr, ram_rd_acc_ptr;

always_ff @(posedge clk) begin: apply_backpressure
    if (reset) begin
        cmd_ready <= 1'b0;
    end else begin
        if (!cmd_pending) begin: instance_ready
            if (cmd_ready && cmd_valid) begin: ack_cmd
                cmd_ready <= 1'b0;
            end else begin: release_backpressure
                cmd_ready <= 1'b1;
            end
        end
    end
end

assign cmd_data_i = cmd_data;

always_ff @(posedge clk) begin: process_cmd
    if (reset) begin
        cmd_pending <= 1'b0;
        cmd_data_reg <= '0;
    end else begin
        if (cmd_ready && cmd_valid) begin: ack_cmd
            cmd_pending <= 1'b1;
            cmd_data_reg <= cmd_data;
            ram_rd_ptr <= cmd_data_i.map.start_row;
        end else if (cmd_pending &&
                (ram_rd_ptr < cmd_data_reg.map.end_row)) begin
            ram_rd_ptr <= ram_rd_ptr + 1'b1;
        end else begin
            cmd_pending <= 1'b0;
        end
    end
end

always_ff @(posedge clk) begin: track_last_cmd
    if (reset) begin
        received_last_cmd <= 1'b0;
        no_more_cmd <= 1'b0;
    end else begin
        if (cmd_last && cmd_ready && cmd_valid) begin: ack_cmd
            received_last_cmd <= 1'b1;
        end else if (received_last_cmd && !cmd_pending) begin
            no_more_cmd <= 1'b1;
        end
    end
end

logic ram_sweep_pending, ram_sweep_done;

always_ff @(posedge clk) begin: sweep_rows
    if (reset) begin
        ram_sweep_pending <= 1'b0;
        ram_sweep_done <= 1'b0;
        ram_rd_acc_ptr <= '0;
    end else begin
        if (no_more_cmd && !ram_sweep_done) begin
            ram_sweep_pending <= 1'b1;
            if (ram_sweep_pending && (int'(ram_rd_acc_ptr) < ROWS)) begin
                ram_rd_acc_ptr <= ram_rd_acc_ptr + 1'b1;
            end else begin
                ram_sweep_pending <= 1'b0;
                ram_sweep_done <= 1'b1;
            end
        end
    end
end

always_ff @(posedge clk) begin: forward_cascade
    if (reset) begin
        cascade_out_valid <= 1'b0;
        cascade_out_intensity <= '0;
    end else begin
        if (ram_sweep_done) begin
            cascade_out_valid <= cascade_in_valid;
            cascade_out_intensity <=
                    cascade_in_intensity +
                    INTENSITY_WIDTH'(42);
        end
    end
end

wire _unused_ok = 1'b0 && &{1'b0,
    START_LIGHT_INDEX,
    STOP_LIGHT_INDEX,
    cmd_last,
    1'b0};

endmodule
`default_nettype wire
