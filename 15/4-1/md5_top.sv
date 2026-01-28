`timescale 1ns/1ps
`default_nettype none

module md5_top #(
    parameter int BLOCK_WIDTH = 512, // bits
    parameter int DIGEST_WIDTH = 128 // bits
) (
    input wire clk,
    input wire reset,
    // Block Input
        output logic md5_block_ready,
        input wire md5_block_valid,
        input wire [BLOCK_WIDTH-1:0] md5_block_data,
    // Digest Output
        output logic digest_valid,
        output logic [DIGEST_WIDTH-1:0] digest_data
);

localparam int ROUNDS = 64;
localparam int WORD_WIDTH = 32;
typedef logic [BLOCK_WIDTH-1:0] md5_block_t;
typedef logic [WORD_WIDTH-1:0] word_t;
typedef logic [DIGEST_WIDTH-1:0] digest_t;

localparam word_t a_init = 32'h67452301;
localparam word_t b_init = 32'hEFCDAB89;
localparam word_t c_init = 32'h98BADCFE;
localparam word_t d_init = 32'h10325476;

localparam logic [ROUNDS*WORD_WIDTH-1:0] CONST_TABLE = {
    32'hd76aa478, 32'he8c7b756, 32'h242070db, 32'hc1bdceee,
    32'hf57c0faf, 32'h4787c62a, 32'ha8304613, 32'hfd469501,
    32'h698098d8, 32'h8b44f7af, 32'hffff5bb1, 32'h895cd7be,
    32'h6b901122, 32'hfd987193, 32'ha679438e, 32'h49b40821,
    32'hf61e2562, 32'hc040b340, 32'h265e5a51, 32'he9b6c7aa,
    32'hd62f105d, 32'h02441453, 32'hd8a1e681, 32'he7d3fbc8,
    32'h21e1cde6, 32'hc33707d6, 32'hf4d50d87, 32'h455a14ed,
    32'ha9e3e905, 32'hfcefa3f8, 32'h676f02d9, 32'h8d2a4c8a,
    32'hfffa3942, 32'h8771f681, 32'h6d9d6122, 32'hfde5380c,
    32'ha4beea44, 32'h4bdecfa9, 32'hf6bb4b60, 32'hbebfbc70,
    32'h289b7ec6, 32'heaa127fa, 32'hd4ef3085, 32'h04881d05,
    32'hd9d4d039, 32'he6db99e5, 32'h1fa27cf8, 32'hc4ac5665,
    32'hf4292244, 32'h432aff97, 32'hab9423a7, 32'hfc93a039,
    32'h655b59c3, 32'h8f0ccc92, 32'hffeff47d, 32'h85845dd1,
    32'h6fa87e4f, 32'hfe2ce6e0, 32'ha3014314, 32'h4e0811a1,
    32'hf7537e82, 32'hbd3af235, 32'h2ad7d2bb, 32'heb86d391};

localparam logic [ROUNDS*5-1:0] LROT_BITS_TABLE = {
    5'd7, 5'd12, 5'd17, 5'd22, 5'd7, 5'd12, 5'd17, 5'd22, 5'd7, 5'd12, 5'd17, 5'd22, 5'd7, 5'd12, 5'd17, 5'd22,
    5'd5, 5'd9,  5'd14, 5'd20, 5'd5, 5'd9,  5'd14, 5'd20, 5'd5,  5'd9, 5'd14, 5'd20, 5'd5,  5'd9, 5'd14, 5'd20,
    5'd4, 5'd11, 5'd16, 5'd23, 5'd4, 5'd11, 5'd16, 5'd23, 5'd4, 5'd11, 5'd16, 5'd23, 5'd4, 5'd11, 5'd16, 5'd23,
    5'd6, 5'd10, 5'd15, 5'd21, 5'd6, 5'd10, 5'd15, 5'd21, 5'd6, 5'd10, 5'd15, 5'd21, 5'd6, 5'd10, 5'd15, 5'd21};

logic md5_block_reg_valid;
md5_block_t md5_block_reg;
logic valid_vec [0:ROUNDS];
word_t a_vec [0:ROUNDS];
word_t b_vec [0:ROUNDS];
word_t c_vec [0:ROUNDS];
word_t d_vec [0:ROUNDS];

always_ff @(posedge clk) begin: flow_control
    if (digest_valid || !md5_block_valid) begin
        md5_block_ready <= 1'b1;
    end else begin
        md5_block_ready <= 1'b0;
    end
end

always_ff @(posedge clk) begin: capture_md5_block_data
    md5_block_reg_valid <= md5_block_ready && md5_block_valid;
    if (md5_block_ready && md5_block_valid) begin
        md5_block_reg <= md5_block_data;
    end
end

assign valid_vec[0] = md5_block_reg_valid;
assign a_vec[0] = a_init;
assign b_vec[0] = b_init;
assign c_vec[0] = c_init;
assign d_vec[0] = d_init;

function int get_msg_word_index(int step);
    if (step < ROUNDS*1/4) begin
        get_msg_word_index = step;
    end else if (step < ROUNDS*2/4) begin
        get_msg_word_index = (5*step+1) % (ROUNDS/4);
    end else if (step < ROUNDS*3/4) begin
        get_msg_word_index = (3*step+5) % (ROUNDS/4);
    end else if (step < ROUNDS*4/4) begin
        get_msg_word_index = (7*step) % (ROUNDS/4);
    end else begin
        $fatal(1, "Invalid step index");
    end
endfunction

genvar i;
generate for (i = 0; i < ROUNDS; i++) begin: per_step

    word_t msg_word, msg_word_le;

    assign msg_word = md5_block_reg[BLOCK_WIDTH-WORD_WIDTH*get_msg_word_index(i)-1-:WORD_WIDTH];
    assign msg_word_le = {msg_word[8-1-:8], msg_word[16-1-:8], msg_word[24-1-:8], msg_word[32-1-:8]};

    md5_step #(
        .ROUND(i),
        .T_CONST(CONST_TABLE[ROUNDS*WORD_WIDTH-WORD_WIDTH*i-1-:WORD_WIDTH]),
        .LROT_BITS(int'(LROT_BITS_TABLE[ROUNDS*5-5*i-1-:5]))
    ) md5_step_i (
        .clk(clk),
        .reset(reset),
        // Per-Step Inputs
            .message(msg_word_le),
        // Upstream / Downstream Steps
            .i_valid(valid_vec[i]),
            .i_a(a_vec[i]), .i_b(b_vec[i]), .i_c(c_vec[i]), .i_d(d_vec[i]),
            .o_valid(valid_vec[i+1]),
            .o_a(a_vec[i+1]), .o_b(b_vec[i+1]), .o_c(c_vec[i+1]), .o_d(d_vec[i+1])
    );

end endgenerate

always_comb begin: dump_step_0_outputs
    if (valid_vec[1]) begin
        $display("Step 0 Outputs: @ cycle %0t: A: 0x%08h, B: 0x%08h, C: 0x%08h, D: 0x%08h", $realtime, a_vec[1], b_vec[1], c_vec[1], d_vec[1]);
    end
end

always_comb begin: vector_tail
    digest_valid = valid_vec[ROUNDS];
    digest_data = {d_vec[ROUNDS], c_vec[ROUNDS], b_vec[ROUNDS], a_vec[ROUNDS]};
end

wire _unused_ok = 1'b0 && &{1'b0,
    1'b0};

endmodule
`default_nettype wire
