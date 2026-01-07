`timescale 1ns/1ps
`default_nettype none

module tile_store #(
    parameter int GRID_BITS,
    parameter int MAX_TILES
)(
    input wire clk,
    // Decoded Line Contents
        input wire end_of_file, // held high
        input wire tile_valid,
        input wire [GRID_BITS-1:0] tile_row,
        input wire [GRID_BITS-1:0] tile_col,
    // Tile Areas
        output logic area_done,
        output logic area_valid,
        output logic [2*GRID_BITS-1:0] area_data
);

localparam ADDR_WIDTH = $clog2(MAX_TILES);

typedef logic [ADDR_WIDTH-1:0] addr_t;
typedef logic [GRID_BITS-1:0] axis_pos_t;
typedef logic [2*GRID_BITS-1:0] coordinates_t;

coordinates_t tile_dpram[2**ADDR_WIDTH-1:0];
initial begin: iverilog_init
    integer i;
    for (i = 0; i < (2**ADDR_WIDTH); i = i + 1) begin
        tile_dpram[i] = '0;
    end
end

coordinates_t tile_a, tile_b;
addr_t addr_a = '0, addr_b = '0, stop_addr = '0;

typedef enum logic [1:0] {
    WAIT_EOF,
    SWEEP_TILE_A,
    INCR_TILE_B,
    DONE
} state_t;
state_t current_state = WAIT_EOF, next_state;

typedef enum logic [1:0] {
    TILE_FILLING,
    TILE_READBACK
} tile_mode_t;
tile_mode_t addr_a_sel, prev_addr_a_sel = TILE_FILLING;
logic addr_b_incr;

always_ff @(posedge clk) current_state <= next_state;

always_comb begin: state_logic
    unique case (current_state)
        WAIT_EOF: begin
            if (!end_of_file) begin
                next_state = WAIT_EOF;
            end else begin
                next_state = SWEEP_TILE_A;
            end
        end
        SWEEP_TILE_A: begin
            if (addr_a < stop_addr) begin
                next_state = SWEEP_TILE_A;
            end else if (addr_b < stop_addr) begin
                next_state = INCR_TILE_B;
            end else begin
                next_state = DONE;
            end
        end
        INCR_TILE_B: begin
            next_state = SWEEP_TILE_A;
        end
        DONE: begin
            next_state = DONE;
        end
    endcase
end

always_comb begin: output_update
    addr_a_sel = TILE_FILLING;
    addr_b_incr = 1'b0;
    area_done = 1'b0;
    unique case (current_state)
        WAIT_EOF: begin
            addr_a_sel = TILE_FILLING;
        end
        SWEEP_TILE_A: begin
            addr_a_sel = TILE_READBACK;

        end
        INCR_TILE_B: begin
            addr_a_sel = TILE_READBACK;
            addr_b_incr = 1'b1;
        end
        DONE: begin
            area_done = 1'b1;
            addr_a_sel = TILE_READBACK;
        end
    endcase
end

always_ff @(posedge clk) begin: addr_a_update
    if (addr_a_sel == TILE_FILLING) begin
        if (tile_valid) begin
            stop_addr <= addr_a;
            addr_a <= addr_a + 1'b1;
        end
    end else begin: readback
        if (addr_a_sel != prev_addr_a_sel) begin: first_readback
            addr_a <= '0;
        end else begin
            if (addr_a < stop_addr) begin
                addr_a <= addr_a + 1'b1;
            end else if (addr_b < stop_addr) begin: restart_from_addr_b
                addr_a <= addr_b + 1'b1;
            end
        end
    end
    prev_addr_a_sel <= addr_a_sel;
end

always_ff @(posedge clk) begin: addr_b_update
    if (addr_b_incr) begin
        addr_b <= addr_b + 1'b1;
    end
end

always_ff @(posedge clk) begin: port_a_rw
    if (tile_valid) begin
        tile_dpram[addr_a] <= {tile_row, tile_col};
    end
    tile_a <= tile_dpram[addr_a];
end

always_ff @(posedge clk) begin: port_b_ro
    tile_b <= tile_dpram[addr_b];
end

initial begin
    area_valid = 1'b0;
end

logic delayed_readback_en = 1'b0;

always_ff @(posedge clk) begin: area_valid_update
    if (!area_valid && delayed_readback_en) begin
        area_valid <= 1'b1;
    end
    delayed_readback_en <= (prev_addr_a_sel == TILE_READBACK);
end

axis_pos_t tile_a_row, tile_a_col, tile_b_row, tile_b_col;
axis_pos_t max_row, min_row, delta_row, max_col, min_col, delta_col;

always_comb begin
    {tile_a_row, tile_a_col} = tile_a;
    {tile_b_row, tile_b_col} = tile_b;
    max_row = (tile_a_row > tile_b_row) ? tile_a_row : tile_b_row;
    min_row = (tile_a_row > tile_b_row) ? tile_b_row : tile_a_row;
    max_col = (tile_a_col > tile_b_col) ? tile_a_col : tile_b_col;
    min_col = (tile_a_col > tile_b_col) ? tile_b_col : tile_a_col;
    delta_row = max_row - min_row;
    delta_col = max_col - min_col;
end

always_ff @(posedge clk)
    area_data <= ((2*GRID_BITS)'(delta_row) + 1) * ((2*GRID_BITS)'(delta_col) + 1);

endmodule
`default_nettype wire
