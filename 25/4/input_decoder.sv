`timescale 1ns/1ps
`default_nettype none

module input_decoder (
    input wire clk,
    // Inbound Byte Stream
        input wire byte_valid,
        input wire [8-1:0] byte_data,
    // Decoded signals
        output logic cell_last,
        output logic cell_valid,
        output logic cell_tpr  // 1: has a TPR, 0: empty
);

// from `man ascii`
typedef enum byte {
    DOT_CHAR = 8'h2E,
    AT_CHAR = 8'h40,
    LF_CHAR = 8'h0A
} char_t;

function automatic logic is_cell(input byte char);
    is_cell = ((char == DOT_CHAR) || (char == AT_CHAR));
endfunction

byte prev_byte_data;
always_ff @(posedge clk) begin: reg_byte_data
    if (byte_valid) begin
        prev_byte_data <= byte_data;
    end
end

always_ff @(posedge clk) begin: decoder
    cell_valid <= 1'b0;
    if (byte_valid) begin
        if (!is_cell(prev_byte_data) && is_cell(byte_data)) begin: first_cell
            cell_last <= 1'b0;
            cell_valid <= 1'b0;
            cell_tpr <= 1'b0;
        end else if (is_cell(prev_byte_data) && is_cell(byte_data)) begin: next_cell
            cell_last <= 1'b0;
            cell_valid <= 1'b1;
            cell_tpr <= (prev_byte_data == AT_CHAR);
        end else if (is_cell(prev_byte_data) && !is_cell(byte_data)) begin: last_cell
            cell_last <= 1'b1;
            cell_valid <= 1'b1;
            cell_tpr <= (prev_byte_data == AT_CHAR);
        end else begin: unexpected
            //$display("Unexpected character: 0x%h (previous 0x%h)", byte_data, prev_byte_data);
        end
    end
end

endmodule
`default_nettype wire
