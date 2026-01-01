`timescale 1ns/1ps
`default_nettype none

module line_decoder #(
    parameter int LINE_WIDTH=160
) (
    input wire clk,
    // Input byte stream
        input wire inbound_valid,
        input wire [8-1:0] inbound_data,
    // Decoded line
        output logic end_of_file,
        output logic line_valid,
        output logic [LINE_WIDTH-1:0] line_data
);

// from `man ascii`
typedef enum byte {
    NULL_CHAR = 8'h00,
    DOT_CHAR = 8'h2E, // `.`
    S_CHAR = 8'h53, // uppercase: `S`
    CARET_CHAR = 8'h5E, // `^`
    LF_CHAR = 8'h0A
} char_t;

logic line_has_splitters = 1'b0;
logic char_is_splitter, char_is_newline;

initial begin
    end_of_file = 1'b0;
    line_valid = 1'b0;
    line_data = '0;
end

assign char_is_splitter = (inbound_data == CARET_CHAR);
assign char_is_newline = (inbound_data == LF_CHAR);

always_ff @(posedge clk) begin: line_sync
    line_valid <= 1'b0;
    if (inbound_valid) begin
        unique case (inbound_data)
            DOT_CHAR, S_CHAR: begin
                line_data <= {line_data[LINE_WIDTH-2:0], char_is_splitter};
            end
            CARET_CHAR: begin
                line_data <= {line_data[LINE_WIDTH-2:0], char_is_splitter};
                line_has_splitters <= 1'b1;
            end
            LF_CHAR: begin
                line_valid <= line_has_splitters;
                line_has_splitters <= 1'b0;
            end
            default: end_of_file <= 1'b1;
        endcase
    end else begin
        if (line_valid) begin: line_data_sent
            line_data <= '0;
        end
    end
end

wire _unused_ok = 1'b0 && &{1'b0,
    char_is_newline,
    1'b0};
endmodule
`default_nettype wire
