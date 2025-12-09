`timescale 1ns / 1ps
`default_nettype none

module adjacent_rop_counter #(
    parameter int COUNT_ROP_WIDTH
) (
    input wire clk,
    // Binary row data
        input wire bin_last,
        input wire bin_valid,
        input wire bin_rop,
    // Adjacent ROP row data
        output logic count_last,
        output logic count_valid,
        output logic [COUNT_ROP_WIDTH-1:0] count_rop
);

typedef logic [1:0] delay_t;
delay_t bin_last_sr = '0, bin_rop_sr = '0;
logic first_rop = 1'b1;

always_ff @(posedge clk) begin
    if (bin_valid) begin
        bin_last_sr <= {bin_last_sr[0], bin_last};
        bin_rop_sr <= {bin_rop_sr[0], bin_rop};
        first_rop <= 1'b0;
    end else if (bin_last) begin
        bin_last_sr <= '0;
        bin_rop_sr <= '0;
        first_rop <= 1'b1;
    end
end

always_ff @(posedge clk) begin
    if (bin_valid) begin
        count_valid <= !first_rop;
        count_rop <= $countones({bin_rop_sr, bin_rop});
    end else if (bin_last_sr[0]) begin: last_count
        count_valid <= !first_rop;
        count_rop <= $countones({bin_rop_sr, bin_rop});
    end else begin
        count_valid <= 1'b0;
    end
end

endmodule
`default_nettype wire
