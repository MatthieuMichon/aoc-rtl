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

localparam int RAM_DATA_WIDTH = 1+INSTRUCTION_WIDTH;
localparam int ADDR_WIDTH = $clog2(MAX_INSTRUCTIONS);

typedef logic [ADDR_WIDTH-1:0] addr_t;
typedef logic [RAM_DATA_WIDTH-1:0] data_t;

data_t [2**ADDR_WIDTH-1:0] ram;
data_t ram_do, skid_buffer;
logic skid_valid;

addr_t wr_ptr = '0, rd_ptr;
(* ASYNC_REG = "TRUE" *) logic wr_last_rd_clk, wr_last_rd_clk_reg;
logic wr_last_rd_clk_reg_prev, wr_last_rd_clk_reg_rising;
logic rd_pending;

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
    end else begin
        wr_last_rd_clk_reg_prev <= wr_last_rd_clk_reg;
        wr_last_rd_clk_reg_rising <= wr_last_rd_clk_reg && !wr_last_rd_clk_reg_prev;
    end
end

always_ff @(posedge rd_clk) begin: read_data
    if (rd_reset) begin
        rd_pending <= 1'b0;
    end else begin
        if (!rd_pending && wr_last_rd_clk_reg_rising) begin: start_read
            rd_pending <= 1'b1;
        end else if (rd_pending) begin
            rd_pending <= !rd_last;
        end
    end
end

always_ff @(posedge rd_clk) begin
    if (rd_reset) begin
        rd_ptr <= '0;
        rd_valid <= 1'b0;
        skid_valid <= 1'b0;
    end else begin
        if (rd_pending && (rd_ready || !skid_valid)) begin: commit_read_op
            rd_ptr <= rd_ptr + 1'b1;
        end
        if (rd_ready) begin
            rd_valid  <= (rd_pending || skid_valid);
            skid_valid <= 1'b0;
        end else if (rd_valid && !skid_valid) begin: backpressure
            skid_buffer  <= ram_do;
            skid_valid <= 1'b1;
        end
    end
end

assign {rd_last, rd_data} = (skid_valid) ? skid_buffer : ram_do;

endmodule
`default_nettype wire
