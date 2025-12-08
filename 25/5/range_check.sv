`timescale 1ns/1ps
`default_nettype none

module range_check #(
    parameter int INGREDIENT_ID_RANGE_WIDTH
)(
    input wire clk,
    // Upstream Range Check Unit
        input wire upstream_id_range_sel,  // 1: ingredient ID, 0: range
        input wire upstream_id_range_valid,
        input wire [INGREDIENT_ID_RANGE_WIDTH-1:0] upstream_id_range_data,
    // Downstream Range Check Unit
        output logic downstream_id_range_sel,  // 1: ingredient ID, 0: range
        output logic downstream_id_range_valid,
        output logic [INGREDIENT_ID_RANGE_WIDTH-1:0] downstream_id_range_data
);

localparam logic INGREDIENT_ID = 1'b1;
typedef logic [INGREDIENT_ID_RANGE_WIDTH-1:0] data_t;

data_t lower_bound, upper_bound;
initial lower_bound = '1;
initial upper_bound = '0;

typedef enum logic [2:0] {
    WAIT_LOWER_BOUND,
    WAIT_UPPER_BOUND,
    WAIT_ID_SEL,
    FILTER_ID
} state_t;
state_t current_state, next_state;
logic sel_lower_bound;
logic sel_upper_bound;
logic forward_range;
logic filter_id;

initial current_state = WAIT_LOWER_BOUND;

always_ff @(posedge clk) begin: state_register
    current_state <= next_state;
end

always_comb begin: state_logic
    unique case (current_state)
        WAIT_LOWER_BOUND: begin
            if (upstream_id_range_sel) begin: trailing_units
                next_state = FILTER_ID;
            end else if (upstream_id_range_valid) begin
                next_state = WAIT_UPPER_BOUND;
            end else begin
                next_state = WAIT_LOWER_BOUND;
            end
        end
        WAIT_UPPER_BOUND: begin
            if (upstream_id_range_valid) begin
                next_state = WAIT_ID_SEL;
            end else begin
                next_state = WAIT_UPPER_BOUND;
            end
        end
        WAIT_ID_SEL: begin
            if (upstream_id_range_sel == INGREDIENT_ID) begin
                next_state = FILTER_ID;
            end else begin
                next_state = WAIT_ID_SEL;
            end
        end
        FILTER_ID: begin
            next_state = FILTER_ID;
        end
        default: begin
            next_state = WAIT_LOWER_BOUND;
        end
    endcase
end

always_comb begin: output_logic
    sel_lower_bound = (current_state == WAIT_LOWER_BOUND);
    sel_upper_bound = (current_state == WAIT_UPPER_BOUND);
    forward_range = (current_state == WAIT_ID_SEL);
    filter_id = (current_state == FILTER_ID);
end

always_ff @(posedge clk) begin: update_range
    if (sel_lower_bound && upstream_id_range_valid) begin
        lower_bound <= upstream_id_range_data;
    end else if (sel_upper_bound && upstream_id_range_valid) begin
        upper_bound <= upstream_id_range_data;
    end
end

function logic is_id_out_of_range(data_t ingredient_id);
    is_id_out_of_range =
        (ingredient_id < lower_bound) ||
        (ingredient_id > upper_bound);
endfunction

always_ff @(posedge clk) begin: output_register
    if (forward_range) begin
        downstream_id_range_sel <= upstream_id_range_sel;
        downstream_id_range_valid <= upstream_id_range_valid;
        downstream_id_range_data <= upstream_id_range_data;
    end else if (upstream_id_range_sel) begin
        downstream_id_range_sel <= upstream_id_range_sel;
        downstream_id_range_valid <= upstream_id_range_valid && is_id_out_of_range(upstream_id_range_data);
        downstream_id_range_data <= upstream_id_range_data;
    end else begin
        downstream_id_range_valid <= '0;
    end
end

endmodule
`default_nettype wire
