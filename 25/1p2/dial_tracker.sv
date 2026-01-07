`timescale 1ns/1ps
`default_nettype none

module dial_tracker #(
    parameter int CLICK_BITS,
    parameter int DIAL_CLICKS
)(
    input wire clk,
    // Decoded Line Contents
        input wire click_valid,
        input wire click_right_left,
        input wire [CLICK_BITS-1:0] click_count,
    // Computed Values
        output logic zero_crossings_valid,
        output logic [CLICK_BITS-1:0] zero_crossings_count
);

localparam int CLICK_CNT_BITS = 1 + CLICK_BITS;
localparam int MAX_CLICKS = 999;
localparam int MAX_CLICKS_MULTIPLE = (1 + MAX_CLICKS / DIAL_CLICKS) * DIAL_CLICKS;
localparam int POSITIVE_BIAS = MAX_CLICKS_MULTIPLE + DIAL_CLICKS; // 1000 + 100

typedef logic [CLICK_CNT_BITS-1:0] click_cnt_t;
click_cnt_t dial;

logic clock_wise_arg_valid, clock_wise_div_valid;
click_cnt_t clock_wise_arg_data, clock_wise_div_quotient, clock_wise_div_remainder;

logic counter_clock_wise_arg_valid, counter_clock_wise_div_valid;
click_cnt_t counter_clock_wise_arg_data, counter_clock_wise_div_quotient_dummy, counter_clock_wise_div_remainder;
logic counter_clock_wise_stage1_valid_dummy, counter_clock_wise_stage2_valid;
click_cnt_t counter_clock_wise_dial_offset, counter_clock_wise_stage1_quotient_dummy, counter_clock_wise_stage1_remainder;
click_cnt_t counter_clock_wise_stage2_arg, counter_clock_wise_stage2_quotient, counter_clock_wise_stage2_remainder_dummy;

initial begin
    dial = 50;
end

// always @(posedge clk) begin: dump_commands
//     if (click_valid) begin
//         if (click_right_left) begin
//             $display("R%0d Dial %0d", click_count, dial);
//         end else begin
//             $display("L%0d Dial %0d", click_count, dial);
//         end
//     end
// end

always @(posedge clk) begin: clock_wise_arg
    if (click_valid && click_right_left) begin
        clock_wise_arg_valid <= 1'b1;
        clock_wise_arg_data <= dial + click_count;
    end else begin
        clock_wise_arg_valid <= 1'b0;
    end
end

always @(posedge clk) begin: counter_clock_wise_stage0
    counter_clock_wise_dial_offset <= CLICK_BITS'(DIAL_CLICKS) - dial;
end

always @(posedge clk) begin: counter_clock_wise_arg
    if (click_valid && !click_right_left) begin
        counter_clock_wise_arg_valid <= 1'b1;
        counter_clock_wise_arg_data <= CLICK_CNT_BITS'(POSITIVE_BIAS) + dial - click_count;
        counter_clock_wise_stage2_arg <=
            counter_clock_wise_stage1_remainder + click_count;
    end else begin
        counter_clock_wise_arg_valid <= 1'b0;
    end
end

fixed_point_div_100 #(
    .ARG_WIDTH(CLICK_CNT_BITS)
) clock_wise_div (
    .clk(clk),
    // Input Argument
        .input_valid(clock_wise_arg_valid),
        .argument(clock_wise_arg_data),
    // Output Quotient and Remainder
        .outputs_valid(clock_wise_div_valid),
        .quotient(clock_wise_div_quotient),
        .remainder(clock_wise_div_remainder)
);

fixed_point_div_100 #(
    .ARG_WIDTH(CLICK_CNT_BITS)
) counter_clock_wise_stage1 (
    .clk(clk),
    // Input Argument
        .input_valid(1'b1), // click_valid is sparsely set which allows precomputing
        .argument(counter_clock_wise_dial_offset),
    // Output Quotient and Remainder
        .outputs_valid(counter_clock_wise_stage1_valid_dummy),
        .quotient(counter_clock_wise_stage1_quotient_dummy),
        .remainder(counter_clock_wise_stage1_remainder)
);

fixed_point_div_100 #(
    .ARG_WIDTH(CLICK_CNT_BITS)
) counter_clock_wise_stage2 (
    .clk(clk),
    // Input Argument
        .input_valid(counter_clock_wise_arg_valid),
        .argument(counter_clock_wise_stage2_arg),
    // Output Quotient and Remainder
        .outputs_valid(counter_clock_wise_stage2_valid),
        .quotient(counter_clock_wise_stage2_quotient),
        .remainder(counter_clock_wise_stage2_remainder_dummy)
);

fixed_point_div_100 #(
    .ARG_WIDTH(CLICK_CNT_BITS)
) counter_clock_wise_div_dial (
    .clk(clk),
    // Input Argument
        .input_valid(counter_clock_wise_arg_valid),
        .argument(counter_clock_wise_arg_data),
    // Output Quotient and Remainder
        .outputs_valid(counter_clock_wise_div_valid),
        .quotient(counter_clock_wise_div_quotient_dummy),
        .remainder(counter_clock_wise_div_remainder)
);

always @(posedge clk) begin: dial_value_update
    if (clock_wise_div_valid) begin
        dial <= clock_wise_div_remainder;
    end else if (counter_clock_wise_div_valid) begin
        dial <= counter_clock_wise_div_remainder;
    end
end

initial begin
    zero_crossings_valid = 1'b0;
end

always @(posedge clk) begin: zero_crossings_sel
    if (clock_wise_div_valid) begin
        zero_crossings_valid <= 1'b1;
        zero_crossings_count <= CLICK_BITS'(clock_wise_div_quotient);
    end else if (counter_clock_wise_stage2_valid) begin
        zero_crossings_valid <= 1'b1;
        zero_crossings_count <= CLICK_BITS'(counter_clock_wise_stage2_quotient);
    end else begin
        zero_crossings_valid <= 1'b0;
    end
end

wire _unused_ok = 1'b0 && &{1'b0,
    clock_wise_div_quotient,
    counter_clock_wise_stage2_quotient,
    counter_clock_wise_stage1_valid_dummy,
    counter_clock_wise_stage1_quotient_dummy,
    counter_clock_wise_stage2_remainder_dummy,
    counter_clock_wise_div_quotient_dummy,
    1'b0};

endmodule
`default_nettype wire
