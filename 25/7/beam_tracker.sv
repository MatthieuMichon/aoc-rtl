`timescale 1ns/1ps
`default_nettype none

module beam_tracker #(
    parameter int LINE_WIDTH
) (
    input wire clk,
    // Splitter locations
        input wire line_valid,
        input wire [LINE_WIDTH-1:0] line_data,
    // Active splitters
        output logic active_splitters_valid,
        output logic [LINE_WIDTH-1:0] active_splitters_data
);

typedef logic [LINE_WIDTH-1:0] line_t;
line_t beams = '0, activated_splitters, deactivated_splitters, unaffected_beams;

assign activated_splitters = beams & line_data;
assign deactivated_splitters = ~beams & line_data;
assign unaffected_beams = beams & ~line_data;

always_ff @(posedge clk) begin
    if (line_valid) begin
        if (!(|beams)) begin: initial_splitter
            active_splitters_valid <= 1'b1;
            active_splitters_data <= line_data;
            beams <= (line_data << 1) | (line_data >> 1);
        end else begin: active_splitter
            active_splitters_valid <= 1'b1;
            active_splitters_data <= activated_splitters;
            beams <= unaffected_beams | (activated_splitters << 1) | (activated_splitters >> 1);
        end
    end else begin
        active_splitters_valid <= 1'b0;
        active_splitters_data <= '0;
    end
end

wire _unused_ok = 1'b0 && &{1'b0,
    deactivated_splitters,
    1'b0};

endmodule
`default_nettype wire
