`timescale 1ns/1ps
`default_nettype none

module light_display_ram #(
    parameter int ADDR_WIDTH,
    parameter int DATA_WIDTH
)(
    input wire clk,
    // Port A: read-only
        input wire [ADDR_WIDTH-1:0] addra,
        output logic [DATA_WIDTH-1:0] doa,
    // Port B: write only
        input wire web,
        input wire [ADDR_WIDTH-1:0] addrb,
        input wire [DATA_WIDTH-1:0] dib
);

typedef logic [DATA_WIDTH-1:0] data_t;
data_t ram[(2**ADDR_WIDTH)-1:0];

initial for (integer i = 0; i < (2**ADDR_WIDTH); i++) ram[i] = {DATA_WIDTH{1'b0}};

always_ff @(posedge clk) begin: port_a
    doa <= ram[addra];
end

always_ff @(posedge clk) begin: port_b
    if (web) begin
        ram[addrb] <= dib;
    end
end

endmodule
`default_nettype wire
