`timescale 1ns/1ps
`default_nettype none

module non_overlapping_pairs_tracker #(
    parameter int STRING_DATA_WIDTH
)(
    input wire clk,
    input wire reset,
    // Decoded Data
        input wire has_repeating_char,
        input wire string_valid,
        input wire [STRING_DATA_WIDTH-1:0] string_data,
    // String Evaluation Result
        output logic string_is_nice // single cycle pulse
);

localparam int BITS_PER_CHAR = $clog2(26);
localparam int MIN_OFFSET = 2;
localparam int CORRELATION_INSTANCES = STRING_DATA_WIDTH/BITS_PER_CHAR - MIN_OFFSET - 1;
localparam int FF_STAGES = 2;

typedef logic [CORRELATION_INSTANCES-1:0] per_instance_t;

per_instance_t string_is_nice_array;

genvar i;

generate
    for (i = 0; i < CORRELATION_INSTANCES; i++) begin: correlation_blocks

        localparam int STRING_OFFSET_BITS = BITS_PER_CHAR * (i + MIN_OFFSET);
        localparam int CORRELATED_BITS = STRING_DATA_WIDTH - STRING_OFFSET_BITS;

        logic [FF_STAGES-1:0] valid_shift_reg = '0;
        logic [CORRELATED_BITS-1:0] lsb_trimmed_string, shifted_string;
        logic [CORRELATED_BITS/BITS_PER_CHAR-1:0] correlated_string;
        logic [CORRELATED_BITS/BITS_PER_CHAR-2:0] string_neighbor_bits;

        assign lsb_trimmed_string = string_data[STRING_DATA_WIDTH-1:STRING_OFFSET_BITS];
        assign shifted_string = string_data[CORRELATED_BITS-1:0];

        always_ff @(posedge clk) valid_shift_reg <= {valid_shift_reg[FF_STAGES-2:0], has_repeating_char && string_valid};
        always_ff @(posedge clk) begin
            for (int j = 0; j < CORRELATED_BITS/BITS_PER_CHAR; j++) begin
                correlated_string[j] <=
                    (lsb_trimmed_string[j*BITS_PER_CHAR+:BITS_PER_CHAR] ==
                        shifted_string[j*BITS_PER_CHAR+:BITS_PER_CHAR]);
            end
        end
        always_ff @(posedge clk) string_neighbor_bits <= (CORRELATED_BITS/BITS_PER_CHAR-1)'(correlated_string & (correlated_string >> 1));
        always_ff @(posedge clk) string_is_nice_array[i] <= valid_shift_reg[FF_STAGES-1] && ($countones(string_neighbor_bits) > 0);
    end
endgenerate

always_ff @(posedge clk) string_is_nice <= ($countones(string_is_nice_array) > 0);

wire _unused_ok = 1'b0 && &{1'b0,
    reset,
    1'b0};

endmodule
`default_nettype wire
