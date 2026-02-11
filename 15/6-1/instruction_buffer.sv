`timescale 1ns/1ps
`default_nettype none

module instruction_buffer #(
    parameter int INSTRUCTION_WIDTH,
    parameter int MAX_INSTRUCTIONS = 512
)(
    // Port A: Write Port
        input wire wr_clk,
        input wire wr_valid,
        input wire [INSTRUCTION_WIDTH-1:0] wr_data,
    // Port B: Read Port
        input wire rd_clk,
        output logic rd_last,
        input wire rd_ready,
        output logic rd_valid,
        output logic [INSTRUCTION_WIDTH-1:0] rd_data
);

localparam int ADDR_WIDTH = $clog2(MAX_INSTRUCTIONS);
localparam int INSTRUCTION_VALID_BIT = INSTRUCTION_WIDTH - 2;

typedef logic [INSTRUCTION_WIDTH-1:0] data_t;
typedef logic [ADDR_WIDTH-1:0] addr_t;

data_t dc_dpram [2**ADDR_WIDTH-1:0];
addr_t wr_ptr = '0, rd_ptr = '0, rd_ptr_reg = '0;
data_t rd_data_reg;
logic rd_data_valid, rd_data_waiting = 1'b0;

always_ff @(posedge wr_clk) begin: wr_ptr_self_incr
    if (wr_valid) begin
        wr_ptr <= wr_ptr + 1'b1;
    end
end

initial begin: simulation_init
    integer i;
    for (i = 0; i < (2**ADDR_WIDTH); i = i + 1) begin
        dc_dpram[i] = {INSTRUCTION_WIDTH{1'b0}};
    end
end

always_ff @(posedge wr_clk) begin: port_a_wr_clk
    if (wr_valid) begin
        dc_dpram[wr_ptr] <= wr_data;
    end
end

always_ff @(posedge rd_clk) begin: port_b_rd_clk
    rd_data <= dc_dpram[rd_ptr];
end

assign rd_data_valid = rd_data_reg[INSTRUCTION_VALID_BIT];

always_ff @(posedge rd_clk) begin: read_data_reg
    if ((rd_data_reg == rd_data) && rd_data_valid) begin: rd_data_stable
        if (!(rd_ready && rd_valid)) begin
            rd_data_waiting <= (rd_ptr_reg == rd_ptr);
        end else begin: transaction_completed
            rd_data_waiting <= 1'b0;
        end
    end else begin
        rd_data_waiting <= 1'b0;
    end
    rd_data_reg <= rd_data;
end

initial begin
    rd_valid = 1'b0;
end

always_ff @(posedge rd_clk) begin: read_flow_ctrl
    if (rd_ready && rd_valid) begin
        rd_ptr <= rd_ptr + 1'b1;
        rd_valid <= 1'b0;
    end else if (rd_data_waiting) begin
        rd_valid <= 1'b1;
    end else begin
        rd_valid <= 1'b0;
    end
    rd_ptr_reg <= rd_ptr;
end

assign rd_last = rd_data_reg[INSTRUCTION_WIDTH-1];

wire _unused_ok = 1'b0 && &{1'b0,
    rd_data_reg,
    1'b0};

endmodule
`default_nettype wire
