`timescale 1ns/1ps
`default_nettype none

module line_decoder #(
    parameter int INBOUND_DATA_WIDTH,
    parameter int SECRET_KEY_WIDTH
)(
    input wire clk,
    input wire reset,
    // Deserialized Data
        input wire inbound_valid,
        input wire [INBOUND_DATA_WIDTH-1:0] inbound_data,
    // Decoded Data
        output logic secret_key_valid, // held high
        output logic [4-1:0] secret_key_chars,
        output logic [SECRET_KEY_WIDTH-1:0] secret_key_value
);

typedef logic [INBOUND_DATA_WIDTH-1:0] inbound_data_t;

// from `man ascii`
typedef enum inbound_data_t {
    LF_CHAR = 8'h0A
} char_t;

always_ff @(posedge clk) begin: output_ctrl
    if (reset) begin
        secret_key_valid <= 1'b0;
        secret_key_chars <= '0;
        secret_key_value <= '0;
    end else if (inbound_valid) begin
        unique case (inbound_data)
            LF_CHAR: secret_key_valid <= 1'b1;
            default: begin
                if (!secret_key_valid) begin
                    secret_key_chars <= secret_key_chars + 4'h1;
                    secret_key_value[SECRET_KEY_WIDTH-32'(8*secret_key_chars)-1-:INBOUND_DATA_WIDTH] <= inbound_data;
                end
            end
        endcase
    end
end

endmodule
`default_nettype wire
