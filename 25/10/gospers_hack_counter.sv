`timescale 1ns/1ps
`default_nettype none

module gospers_hack_counter #(
    parameter int WIDTH
)(
    input wire clk,
    input wire reset,
    output logic done,
    output logic valid,
    output logic [WIDTH-1:0] bits
);

typedef logic [WIDTH-1:0] bits_t;

logic [$clog2(WIDTH+1)-1:0] nb_bits_set;
bits_t x, max_x;
bits_t lowest_set_bit;
bits_t increment;
bits_t flipped_bits;
bits_t alignment;

always_comb begin
    max_x = ((1 << nb_bits_set) - 1) << ($bits(nb_bits_set)'(WIDTH) - nb_bits_set);
    lowest_set_bit = x & -x;
    increment = x + lowest_set_bit;
    flipped_bits = x ^ increment;
    alignment = (flipped_bits >> 2) / lowest_set_bit;
end

always_ff @(posedge clk) begin
    if (reset) begin
        done <= 1'b0;
        valid <= 1'b0;
        bits <= '0;
        nb_bits_set <= 1;
        x <= 1;
    end else if (!done) begin
        valid <= 1'b1;
        bits <= x;
        if (x < max_x) begin: gospers_hack
            x <= increment | alignment;
        end else begin: last_code_for_nb_bits_set
            if (nb_bits_set < $bits(nb_bits_set)'(WIDTH)) begin: incr_hamming_weight
                x <= (1 << (nb_bits_set + 1)) - 1;
                nb_bits_set <= nb_bits_set + 1;
            end else begin: completed_sweep
                done <= 1'b1;
                valid <= 1'b0;
            end
        end
    end
end

endmodule
`default_nettype wire
