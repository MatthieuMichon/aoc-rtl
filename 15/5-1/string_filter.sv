`timescale 1ns/1ps
`default_nettype none

module string_filter #(
    parameter int INBOUND_DATA_WIDTH
)(
    input wire clk,
    input wire reset,
    // Deserialized Data
        input wire inbound_valid,
        input wire [INBOUND_DATA_WIDTH-1:0] inbound_data,
    // Decoded Data
        output logic end_of_file,
        output logic string_is_nice
);

localparam int MIN_REQUIRED_VOWELS = 3;
localparam int STRING_CHARS = 16;
localparam int STRING_WIDTH = 8*STRING_CHARS;
typedef logic [INBOUND_DATA_WIDTH-1:0] inbound_data_t;
typedef logic [$clog2(STRING_CHARS)-1:0] char_index_t;
typedef logic [STRING_WIDTH-1:0] string_t;

// from `man ascii`
typedef enum inbound_data_t {
    NULL_CHAR = 8'h00,
    LF_CHAR = 8'h0A,
    A_CHAR = 8'h61, // lower-case 'a'
    B_CHAR = 8'h62, // lower-case 'b'
    C_CHAR = 8'h63, // lower-case 'c'
    D_CHAR = 8'h64, // lower-case 'd'
    E_CHAR = 8'h65, // lower-case 'e'
    I_CHAR = 8'h69, // lower-case 'i'
    O_CHAR = 8'h6F, // lower-case 'o'
    P_CHAR = 8'h70, // lower-case 'p'
    Q_CHAR = 8'h71, // lower-case 'q'
    U_CHAR = 8'h75, // lower-case 'u'
    X_CHAR = 8'h78, // lower-case 'x'
    Y_CHAR = 8'h79, // lower-case 'y'
    Z_CHAR = 8'h7A // lower-case 'z'
} char_t;

inbound_data_t prev_char;
char_index_t vowel_count;
logic has_same_consecutive_letters, has_forbidden_substrings;

function automatic logic is_char_vowel(inbound_data_t char);
    unique case (char)
        A_CHAR: is_char_vowel = 1'b1;
        E_CHAR: is_char_vowel = 1'b1;
        I_CHAR: is_char_vowel = 1'b1;
        O_CHAR: is_char_vowel = 1'b1;
        U_CHAR: is_char_vowel = 1'b1;
        default: is_char_vowel = 1'b0;
    endcase
endfunction

function automatic logic is_substring_forbidden(inbound_data_t prev_char_, current_char);
    inbound_data_t [1:0] substring;
    substring = {prev_char_, current_char};
    unique case (substring)
        {A_CHAR, B_CHAR}: return 1'b1;
        {C_CHAR, D_CHAR}: return 1'b1;
        {P_CHAR, Q_CHAR}: return 1'b1;
        {X_CHAR, Y_CHAR}: return 1'b1;
        default: return 1'b0;
    endcase
endfunction

always_ff @(posedge clk) begin: reg_inbound_char
    if (reset) begin
        prev_char <= NULL_CHAR;
    end else begin
        if (inbound_valid) begin
            prev_char <= inbound_data;
        end
    end
end

always_ff @(posedge clk) begin: count_vowels
    if (reset) begin
        vowel_count <= '0;
    end else begin
        if (inbound_valid) begin
            unique case (inbound_data)
                LF_CHAR: vowel_count <= '0;
                NULL_CHAR: vowel_count <= '0;
                default: begin
                    if (is_char_vowel(inbound_data)) begin
                        vowel_count <= vowel_count + 1;
                    end
                end
            endcase
        end
    end
end

always_ff @(posedge clk) begin: check_consecutive_letters
    if (reset) begin
        has_same_consecutive_letters <= 1'b0;
    end else begin
        if (inbound_valid) begin
            unique case (inbound_data)
                LF_CHAR: has_same_consecutive_letters <= 1'b0;
                NULL_CHAR: has_same_consecutive_letters <= 1'b0;
                default: begin
                    if (prev_char == inbound_data) begin
                        has_same_consecutive_letters <= 1'b1;
                    end
                end
            endcase
        end
    end
end

always_ff @(posedge clk) begin: check_forbidden_substrings
    if (reset) begin
        has_forbidden_substrings <= 1'b0;
    end else begin
        if (inbound_valid) begin
            unique case (inbound_data)
                LF_CHAR: has_forbidden_substrings <= 1'b0;
                default: begin
                    if (is_substring_forbidden(prev_char, inbound_data)) begin
                        has_forbidden_substrings <= 1'b1;
                    end
                end
            endcase
        end
    end
end

always_ff @(posedge clk) begin: output_ctrl
    if (reset) begin
        end_of_file <= 1'b0;
        string_is_nice <= 1'b0;
    end else begin
        string_is_nice <= 1'b0;
        if (inbound_valid) begin
            unique case (inbound_data)
                LF_CHAR: string_is_nice <=
                    (int'(vowel_count) >= MIN_REQUIRED_VOWELS) &&
                    has_same_consecutive_letters &&
                    !has_forbidden_substrings;
                NULL_CHAR: end_of_file <= 1'b1;
                default: begin
                end
            endcase
        end
    end
end

wire _unused_ok = 1'b0 && &{1'b0,
    1'b0};

endmodule
`default_nettype wire
