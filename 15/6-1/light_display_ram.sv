`timescale 1ns/1ps
`default_nettype none

module light_display_ram #(
    parameter int ADDR_WIDTH,
    parameter int DATA_WIDTH
)(
    input wire clk,
    // Port A: R/W light state update
        input wire wea,
        input wire [ADDR_WIDTH-1:0] addra,
        input wire [DATA_WIDTH-1:0] dia,
        output logic [DATA_WIDTH-1:0] doa,
    // Port B: RO final lit lights count
        input wire [ADDR_WIDTH-1:0] addrb,
        output logic [DATA_WIDTH-1:0] dob
);

typedef logic [DATA_WIDTH-1:0] data_t;
data_t ram[(2**ADDR_WIDTH)-1:0];

initial begin
    integer i;
    for (i = 0; i < (2**ADDR_WIDTH); i = i + 1) begin
        ram[i] = {DATA_WIDTH{1'b0}};
    end
end

always_ff @(posedge clk) begin: port_a
    if (wea) begin
        ram[addra] <= dia;
    end
    doa <= ram[addra];
end

always_ff @(posedge clk) begin: port_b
    dob <= ram[addrb];
end

endmodule
`default_nettype wire
