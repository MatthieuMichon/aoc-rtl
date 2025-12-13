`timescale 1ns/1ps
`default_nettype none

module input_decoder #(
    parameter int NODE_CHARS = 3, // do not override
    parameter int NODE_BIN_BITS = 5, // do not override
    parameter int NODE_WIDTH = NODE_CHARS*NODE_BIN_BITS // do not override
)(
    input wire clk,
    // Inbound Byte Stream
        input wire byte_valid,
        input wire [8-1:0] byte_data,
    // Decoded signals
        output logic decoding_done,
        output logic edge_valid,
        output logic src_node_valid, // for early src_node LUT registration
        output logic [NODE_WIDTH-1:0] src_node,
        output logic [NODE_WIDTH-1:0] dst_node
);

typedef logic [NODE_WIDTH-1:0] node_t;

// from `man ascii`
typedef enum byte {
    A_CHAR = 8'h61, // lowercase: `a`
    Z_CHAR = 8'h7A, // lowercase: `z`
    COLON_CHAR = 8'h3A, // `:`
    SPACE_CHAR = 8'h20,
    LF_CHAR = 8'h0A
} char_t;

function bit char_is_letter(byte char);
    char_is_letter = (char >= A_CHAR && char <= Z_CHAR);
endfunction

logic [8-1:0] prev_byte_data;
always_ff @(posedge clk)
    if (byte_valid)
        prev_byte_data <= byte_data;

logic src_node_is_set = 1'b0;

always_ff @(posedge clk) begin
    decoding_done <= 1'b0;
    edge_valid <= 1'b0;
    src_node_valid <= 1'b0;
    if (byte_valid) begin
        if (!src_node_is_set) begin: lhs
            if (char_is_letter(byte_data)) begin
                src_node <= {NODE_BIN_BITS'(byte_data-A_CHAR), src_node[$high(src_node)-:2*NODE_BIN_BITS]};
            end else if (byte_data == COLON_CHAR) begin
                src_node_valid <= 1'b1;
                src_node_is_set <= 1'b1;
            end else begin: eof
                decoding_done <= 1'b1;
            end
        end else begin: rhs
            if (char_is_letter(byte_data)) begin
                dst_node <= {NODE_BIN_BITS'(byte_data-A_CHAR), dst_node[$high(dst_node)-:2*NODE_BIN_BITS]};
            end else if (char_is_letter(prev_byte_data)) begin: special_char
                edge_valid <= 1'b1;
                if (byte_data == LF_CHAR) begin: end_of_line
                    src_node_is_set <= 1'b0;
                end
            end
        end
    end
end

endmodule
`default_nettype wire
