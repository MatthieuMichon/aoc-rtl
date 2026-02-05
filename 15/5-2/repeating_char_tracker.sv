`timescale 1ns/1ps
`default_nettype none

module repeating_char_tracker #(
    parameter int INBOUND_DATA_WIDTH,
    parameter int STRING_DATA_WIDTH
)(
    input wire clk,
    input wire reset,
    // Deserialized Data
        input wire inbound_valid,
        input wire [INBOUND_DATA_WIDTH-1:0] inbound_data,
    // Decoded Data
        output logic end_of_file,
        output logic has_repeating_char, // sync with string_valid
        output logic string_valid,
        output logic [STRING_DATA_WIDTH-1:0] string_data
);

localparam int BITS_PER_CHAR = $clog2(26);

typedef logic [INBOUND_DATA_WIDTH-1:0] inbound_data_t;
typedef logic [STRING_DATA_WIDTH-1:0] string_t;

// from `man ascii`
typedef enum inbound_data_t {
    NULL_CHAR = 8'h00,
    LF_CHAR = 8'h0A,
    A_CHAR = 8'h61, // lower-case 'a'
    Z_CHAR = 8'h7A // lower-case 'z'
} char_t;

inbound_data_t [0:1] char_history;

function automatic logic is_char_letter(inbound_data_t char);
    return (char >= A_CHAR && char <= Z_CHAR);
endfunction

always_ff @(posedge clk) begin: track_char
    if (reset) begin
        char_history <= {NULL_CHAR, NULL_CHAR};
    end else begin
        if (inbound_valid) begin
            char_history <= {inbound_data, char_history[0]};
        end
    end
end

always_ff @(posedge clk) begin: check_repeating_chars
    if (reset) begin
        has_repeating_char <= 1'b0;
    end else begin
        if (string_valid) begin
            has_repeating_char <= 1'b0;
        end
        if (inbound_valid) begin
            if (is_char_letter(inbound_data) &&
                    is_char_letter(char_history[0]) &&
                    is_char_letter(char_history[1])) begin
                if (inbound_data == char_history[1]) begin
                    has_repeating_char <= 1'b1;
                end
            end
        end
    end
end

always_ff @(posedge clk) begin: output_ctrl
    if (reset) begin
        end_of_file <= 1'b0;
        string_valid <= 1'b0;
    end else begin
        string_valid <= 1'b0;
        if (inbound_valid) begin
            unique case (inbound_data)
                NULL_CHAR: begin
                    end_of_file <= 1'b1;
                end
                LF_CHAR: begin
                    string_valid <= 1'b1;
                end
                default: begin
                    string_data <= STRING_DATA_WIDTH'({string_data, inbound_data[BITS_PER_CHAR-1:0]});
                end
            endcase
        end
    end
end

wire _unused_ok = 1'b0 && &{1'b0,
    1'b0};

endmodule
`default_nettype wire
