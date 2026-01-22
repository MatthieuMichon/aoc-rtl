`timescale 1ns/1ps
`default_nettype none

module char_decoder #(
    parameter int INBOUND_DATA_WIDTH
)(
    input wire clk,
    input wire reset,
    // Deserialized Data
        input wire inbound_valid,
        input wire [INBOUND_DATA_WIDTH-1:0] inbound_data,
    // Decoded Data
        output logic end_of_file,
        output logic shift_valid,
        output logic [4-1:0] shift_direction // one-hot: NESW
);

typedef logic [INBOUND_DATA_WIDTH-1:0] inbound_data_t;

// from `man ascii`
typedef enum inbound_data_t {
    LF_CHAR = 8'h0A,
    LT_CHAR = 8'h3C, // '<'
    GT_CHAR = 8'h3E, // '>'
    CARET_CHAR = 8'h5E, // '^'
    V_CHAR = 8'h76 // lower-case 'v'
} char_t;

typedef enum logic [4-1:0] {
    N_DIR = 4'b1000,
    E_DIR = 4'b0100,
    S_DIR = 4'b0010,
    W_DIR = 4'b0001
} dir_t;

always_ff @(posedge clk) begin: output_ctrl
    if (reset) begin
        end_of_file <= 1'b0;
        shift_valid <= 1'b0;
        shift_direction <= '0;
    end else begin
        shift_valid <= 1'b0;
        if (inbound_valid) begin
            shift_valid <= 1'b1;
            unique case (inbound_data)
                CARET_CHAR: shift_direction <= N_DIR;
                GT_CHAR: shift_direction <= E_DIR;
                V_CHAR: shift_direction <= S_DIR;
                LT_CHAR: shift_direction <= W_DIR;
                default: begin
                    end_of_file <= 1'b1;
                    shift_valid <= 1'b0;
                    shift_direction <= '0;
                end
            endcase
        end
    end
end

endmodule
`default_nettype wire
