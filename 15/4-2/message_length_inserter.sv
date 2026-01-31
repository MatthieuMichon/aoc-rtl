`timescale 1ns/1ps
`default_nettype none

module message_length_inserter #(
    parameter int MAX_MSG_LENGTH, // bytes
    parameter int MD5_BLOCK_LENGTH = 64 // bytes
) (
    input wire clk,
    input wire reset,
    // Message Without Length
        output logic msg_ready,
        input wire msg_valid,
        input wire [$clog2(MAX_MSG_LENGTH)-1:0] msg_length, // bytes
        input wire [8*MAX_MSG_LENGTH-1:0] msg_data,
    // MD5 Block With Length
        input wire md5_block_ready,
        output logic md5_block_valid,
        output logic [8*MD5_BLOCK_LENGTH-1:0] md5_block_data
);

localparam int BLOCK_LENGTH_BITS = 64;

typedef logic [8*MD5_BLOCK_LENGTH-1:0] md5_block_t;
typedef logic [BLOCK_LENGTH_BITS-1:0] block_len_t;

md5_block_t md5_block_payload;
block_len_t msg_length_cast, msg_length_le; // little-endian

assign msg_ready = md5_block_ready || !msg_valid;

always_comb begin: swap_block_length_bytes
    msg_length_cast = BLOCK_LENGTH_BITS'(8*msg_length);
    for (int i = 0; i < BLOCK_LENGTH_BITS/8; i++) begin: per_byte
        msg_length_le[8*i+:8] = msg_length_cast[8*(BLOCK_LENGTH_BITS/8-i-1)+:8];
    end
end

assign md5_block_payload = {msg_data, {8*MD5_BLOCK_LENGTH-8*MAX_MSG_LENGTH{1'b0}}};
always_ff @(posedge clk) begin: dummy_forward
    if (reset) begin
        md5_block_valid <= '0;
    end else begin
        if (msg_ready) begin
            md5_block_valid <= msg_valid;
            if (msg_valid) begin
                md5_block_data <= md5_block_payload | (8*MD5_BLOCK_LENGTH)'(msg_length_le);
            end
        end
    end
end

wire _unused_ok = 1'b0 && &{1'b0,
    msg_length,
    1'b0};

endmodule
`default_nettype wire
