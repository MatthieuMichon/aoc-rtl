`timescale 1ns/1ps
`default_nettype none

module line_decoder #(
    parameter int MAX_WIRING_WIDTH
)(
    input wire clk,
    // Inbound Byte Stream
        input wire inbound_valid,
        input wire [8-1:0] inbound_byte,
    // Decoded Line Contents
        output logic end_of_file, // held high
        output logic end_of_line, // pulsed outside of a valid cycle
        output logic wiring_valid,
        output logic [MAX_WIRING_WIDTH-1:0] wiring_data
);

// from `man ascii`
typedef enum byte {
    NULL_CHAR = 8'h00,
    LF_CHAR = 8'h0A,
    SPACE_CHAR = 8'h20,
    HASH_CHAR = 8'h23, // `#`
    L_PAREN_CHAR = 8'h28, // `(`
    R_PAREN_CHAR = 8'h29, // `)`
    COMA_CHAR = 8'h2C, // `,`
    DOT_CHAR = 8'h2E, // `.`
    ZERO_CHAR = 8'h30, // `0`
    NINE_CHAR = 8'h39, // `9`
    R_BRACKET_CHAR = 8'h5D, // `]`
    L_BRACE_CHAR = 8'h7B // `{`
} char_t;

localparam int BIT_CNT_WIDTH = $clog2(MAX_WIRING_WIDTH);
typedef logic [MAX_WIRING_WIDTH-1:0] wiring_t;
typedef logic [BIT_CNT_WIDTH-1:0] bit_cnt_t;

wiring_t light_wiring = '0, button_wiring = '0;
bit_cnt_t light_bit_index = '0;

always_ff @(posedge clk) begin: decode_light_wiring
    if (inbound_valid) begin
        unique case (inbound_byte)
            DOT_CHAR, HASH_CHAR: begin
                light_wiring[light_bit_index] <= (inbound_byte == HASH_CHAR);
                light_bit_index <= light_bit_index + 1;
            end
            LF_CHAR: begin
                light_wiring <= '0;
                light_bit_index <= '0;
            end
            default: begin
            end
        endcase
    end
end

function automatic logic is_digit(input byte char);
    is_digit = ((char >= ZERO_CHAR) && (char <= NINE_CHAR));
endfunction

always_ff @(posedge clk) begin: decode_buttons_wiring
    if (inbound_valid) begin
        unique case (inbound_byte)
            SPACE_CHAR: begin
                button_wiring <= '0;
            end
            default: begin
                if (is_digit(inbound_byte)) begin
                    button_wiring <= button_wiring + (1 << (inbound_byte - ZERO_CHAR));
                end
            end
        endcase
    end
end

initial begin
    end_of_file = 1'b0;
    end_of_line = 1'b0;
    wiring_valid = 1'b0;
    wiring_data = '0;
end

always_ff @(posedge clk) begin: output_sel
    end_of_line <= 1'b0;
    wiring_valid <= 1'b0;
    if (inbound_valid) begin
        unique case (inbound_byte)
            R_BRACKET_CHAR: begin: commit_light_data
                wiring_valid <= 1'b1;
                wiring_data <= light_wiring;
            end
            R_PAREN_CHAR: begin: commit_button_data
                wiring_valid <= 1'b1;
                wiring_data <= button_wiring;
            end
            LF_CHAR: begin
                end_of_line <= 1'b1;
            end
            NULL_CHAR: begin
                end_of_file <= 1'b1;
            end
            default: begin
            end
        endcase
    end
end

endmodule
`default_nettype wire
