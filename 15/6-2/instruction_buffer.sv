`timescale 1ns/1ps
`default_nettype none

module instruction_buffer #(
    parameter int INSTRUCTION_WIDTH,
    parameter int MAX_INSTRUCTIONS = 512
)(
    // Incoming
        input wire wr_clk,
        input wire wr_last,
        input wire wr_valid,
        input wire [INSTRUCTION_WIDTH-1:0] wr_data,
    // Outgoing
        input wire rd_clk,
        input wire rd_reset,
        output logic rd_last,
        input wire rd_ready,
        output logic rd_valid,
        output logic [INSTRUCTION_WIDTH-1:0] rd_data
);

localparam int ADDR_WIDTH = $clog2(MAX_INSTRUCTIONS);
localparam int RAM_DATA_WIDTH = 1+INSTRUCTION_WIDTH;

typedef logic [ADDR_WIDTH-1:0] addr_t;
typedef logic [RAM_DATA_WIDTH-1:0] data_t;

data_t [2**ADDR_WIDTH-1:0] ram;
data_t ram_do, skid_buffer;
logic skid_valid;

addr_t wr_ptr = '0, rd_ptr;
(* ASYNC_REG = "TRUE" *) logic wr_last_rd_clk, wr_last_rd_clk_reg;
logic wr_last_rd_clk_reg_prev, wr_last_rd_clk_reg_rising, wr_completed;

always_ff @(posedge wr_clk) begin: wr_ptr_self_incr
    if (wr_valid) begin
        wr_ptr <= wr_ptr + 1'b1;
    end
end

initial for (int i = 0; i < (2**ADDR_WIDTH); i++) ram[i] = '0;

always_ff @(posedge wr_clk) begin: port_a_wr_clk
    if (wr_valid) begin
        ram[wr_ptr] <= {wr_last, wr_data};
    end
end

always_ff @(posedge rd_clk) begin: port_b_rd_clk
    ram_do <= ram[rd_ptr];
end

always_ff @(posedge rd_clk) begin: cross_cdc_flag
    wr_last_rd_clk <= wr_last;
    wr_last_rd_clk_reg <= wr_last_rd_clk;
end

always_ff @(posedge rd_clk) begin: track_last_rising
    if (rd_reset) begin
        wr_last_rd_clk_reg_prev <= 1'b0;
        wr_last_rd_clk_reg_rising <= 1'b0;
        wr_completed <= 1'b0;
    end else begin
        wr_last_rd_clk_reg_prev <= wr_last_rd_clk_reg;
        wr_last_rd_clk_reg_rising <= wr_last_rd_clk_reg && !wr_last_rd_clk_reg_prev;
        if (wr_last_rd_clk_reg_rising) begin
            wr_completed <= 1'b1;
        end
    end
end

logic ram_rd_en;

always_ff @(posedge rd_clk) begin: update_rd_ptr
    if (rd_reset) begin
        rd_ptr <= '0;
        ram_rd_en <= 1'b0;
    end else begin
        if (wr_completed) begin
            if (rd_ready && rd_valid) begin: rd_enable
                if (!rd_last) begin: not_last_instruction
                    rd_ptr <= rd_ptr + 1'b1;
                    ram_rd_en <= 1'b1;
                end else begin
                    rd_ptr <= '0;
                end
            end else begin
                ram_rd_en <= 1'b0;
            end
        end
    end
end

always_ff @(posedge rd_clk) begin: manage_skid_buffer
    if (rd_reset) begin
        rd_valid <= 1'b0;
        skid_valid <= 1'b0;
        skid_buffer <= '0;
    end else begin
        if (wr_completed && !(rd_last && rd_ready && rd_valid)) begin: forward_data
            rd_valid <= 1'b1;
            if (!skid_valid && !rd_ready) begin: buffer_data
                skid_valid <= ram_rd_en;
                skid_buffer <= ram_do;
            end else if (!skid_valid && rd_ready) begin
                skid_buffer <= ram_do;
            end else if (skid_valid && !rd_ready) begin
                skid_valid <= ram_rd_en;
            end else if (skid_valid && rd_ready) begin
                skid_valid <= 1'b0;
            end
        end else begin
            rd_valid <= 1'b0;
            skid_valid <= 1'b0;
        end
    end
end

assign {rd_last, rd_data} = (skid_valid) ? skid_buffer : ram_do;

endmodule
`default_nettype wire
