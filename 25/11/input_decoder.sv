`timescale 1ns/1ps
`default_nettype none

module input_decoder #(
    parameter int DEVICE_CHARS = 3, // do not override
    parameter int DEVICE_BIN_BITS = 5, // do not override
    parameter int DEVICE_WIDTH = DEVICE_CHARS*DEVICE_BIN_BITS // do not override
)(
    input wire clk,
    // Inbound Byte Stream
        input wire byte_valid,
        input wire [8-1:0] byte_data,
    // Decoded signals
        output logic end_of_file,
        output logic connection_valid,
        output logic connection_last, // for a given device
        output logic [DEVICE_WIDTH-1:0] device,
        output logic [DEVICE_WIDTH-1:0] next_device
);

typedef logic [DEVICE_WIDTH-1:0] device_t;

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

logic device_is_set = 1'b0;

always_ff @(posedge clk) begin
    connection_last <= 1'b0;
    connection_valid <= 1'b0;
    if (byte_valid) begin
        if (!device_is_set) begin: lhs
            if (char_is_letter(byte_data)) begin
                device <= {DEVICE_BIN_BITS'(byte_data-A_CHAR), device[$high(device)-:2*DEVICE_BIN_BITS]};
            end else if (byte_data == COLON_CHAR) begin
                device_is_set <= 1'b1;
            end else begin: eof
                end_of_file <= 1'b1;
            end
        end else begin: rhs
            if (char_is_letter(byte_data)) begin
                next_device <= {DEVICE_BIN_BITS'(byte_data-A_CHAR), next_device[$high(device)-:2*DEVICE_BIN_BITS]};
            end else if (char_is_letter(prev_byte_data)) begin: special_char
                connection_valid <= 1'b1;
                if (byte_data == LF_CHAR) begin: end_of_line
                    connection_last <= 1'b1;
                    device_is_set <= 1'b0;
                end
            end
        end
    end
end

endmodule
`default_nettype wire
