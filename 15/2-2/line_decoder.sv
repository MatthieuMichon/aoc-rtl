`timescale 1ns/1ps
`default_nettype none

module line_decoder #(
    parameter int SIZE_WIDTH
)(
    input wire clk,
    input wire reset,
    // Inbound Byte Stream
        input wire inbound_valid,
        input wire [8-1:0] inbound_byte,
    // Decoded Line Contents
        output logic end_of_file, // held high
        output logic size_valid,
        output logic [SIZE_WIDTH-1:0] length,
        output logic [SIZE_WIDTH-1:0] width,
        output logic [SIZE_WIDTH-1:0] height
);

// from `man ascii`
typedef enum byte {
    LF_CHAR = 8'h0A,
    ZERO_CHAR = 8'h30, // `0`
    NINE_CHAR = 8'h39, // `9`
    X_CHAR = 8'h78 // lower-case `x`
} char_t;

typedef logic [SIZE_WIDTH-1:0] size_t;
logic [8-1:0] prev_inbound_byte = '0;
logic length_set = 1'b0;
size_t size = '0;

function automatic logic is_digit(input byte char);
    is_digit = ((char >= ZERO_CHAR) && (char <= NINE_CHAR));
endfunction

always_ff @(posedge clk) begin: decimal_accumulator
    if (inbound_valid) begin
        if (!is_digit(prev_inbound_byte) && is_digit(inbound_byte)) begin: first_digit
            size <= SIZE_WIDTH'(inbound_byte - ZERO_CHAR);
        end else if (is_digit(prev_inbound_byte) && is_digit(inbound_byte)) begin: next_digit
            size <= 10 * size + SIZE_WIDTH'(inbound_byte - ZERO_CHAR);
        end
        prev_inbound_byte <= inbound_byte;
    end
end

always_ff @(posedge clk) begin: output_ctrl
    if (reset) begin
        end_of_file <= 1'b0;
        size_valid <= 1'b0;
    end else begin
        size_valid <= 1'b0;
        if (inbound_valid) begin
            unique case (inbound_byte)
                X_CHAR: begin
                    if (!length_set) begin: recevied_first_arg
                        length_set <= 1'b1;
                        length <= size;
                    end else begin: recevied_second_arg
                        width <= size;
                    end
                end
                LF_CHAR: begin
                    if (prev_inbound_byte != LF_CHAR) begin: received_third_arg
                        size_valid <= 1'b1;
                    end else begin: double_new_line
                        end_of_file <= 1'b1;
                    end
                    height <= size;
                    length_set <= 1'b0;
                end
                default: begin
                    if (!is_digit(inbound_byte)) begin: bail_out_on_non_text_char
                        end_of_file <= 1'b1;
                    end
                end
            endcase
        end
    end
end

endmodule
`default_nettype wire
