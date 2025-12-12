`timescale 1ns/1ps
`default_nettype none

module forward_pass_processor #(
    parameter int DEVICE_CHARS = 3, // do not override
    parameter int DEVICE_BIN_BITS = 5, // do not override
    parameter int DEVICE_WIDTH = DEVICE_CHARS*DEVICE_BIN_BITS, // do not override
    parameter int MAX_TOTAL_RHS_DEVICES = 2048, // total right-hand side devices
    parameter int MAX_OUTPUTS = 30 // maximum number of connections per device
)(
    input wire clk,
    // Connection Entries
        input wire end_of_file,
        input wire connection_valid,
        input wire connection_last, // for a given device
        input wire [DEVICE_WIDTH-1:0] device,
        input wire [DEVICE_WIDTH-1:0] next_device,
    // Path Count Engine
        output logic queue_empty,
        output logic queue_push,
        input wire [DEVICE_WIDTH-1:0] queue_device,
        output logic [DEVICE_WIDTH-1:0] queue_count_incr,
        output logic [8-1:0] queue_count_incr
);

localparam RHS_ADDR_WIDTH = $clog2(MAX_TOTAL_RHS_DEVICES);
localparam OUTPUT_WIDTH = $clog2(MAX_OUTPUTS);
typedef logic [RHS_ADDR_WIDTH-1:0] rhs_addr_t;
typedef logic [OUTPUT_WIDTH-1:0] output_count_t;

typedef struct packed {
    rhs_addr_t start_ptr;
    output_count_t outputs;
} adjacency_entry_t;

typedef logic [DEVICE_WIDTH-1:0] device_t;
typedef logic [8-1:0] path_count_t;

localparam byte A_CHAR = 8'h61; // lowercase: `a`

function device_t device_from_ascii(string char);
    device_from_ascii[15-1-:5] = 5'(char[2] - A_CHAR);
    device_from_ascii[10-1-:5] = 5'(char[1] - A_CHAR);
    device_from_ascii[5-1-:5] = 5'(char[0] - A_CHAR);
endfunction

function string device_to_ascii(device_t device_);
    device_to_ascii = "   ";
    device_to_ascii[2] = 8'(device_[15-1-:5] + A_CHAR);
    device_to_ascii[1] = 8'(device_[10-1-:5] + A_CHAR);
    device_to_ascii[0] = 8'(device_[5-1-:5] + A_CHAR);
endfunction

adjacency_entry_t adjacency_list[2**DEVICE_WIDTH-1:0];
device_t connection_list[2**RHS_ADDR_WIDTH-1:0];
rhs_addr_t ptr = '0;
output_count_t output_cnt = '0;

always_ff @(posedge clk) begin: adjacency_store
    if (connection_valid) begin
        connection_list[ptr+output_cnt] <= next_device;
        $display("W connection_list[0x%03x] <- {0x%04x-%s}", ptr+output_cnt, next_device, device_to_ascii(next_device));
        if (connection_last) begin
            adjacency_list[device].start_ptr <= ptr;
            adjacency_list[device].outputs <= 1 + output_cnt;
            $display("W adjacency_list[0x%04x-%s] <- {0x%03x, 0x%02x}", device, device_to_ascii(device), ptr, 1 + output_cnt);
            ptr <= ptr + (1 + output_cnt);
            output_cnt <= '0;
        end else begin
            output_cnt <= output_cnt + 1;
        end
    end
end


localparam device_t start_device = device_from_ascii("you");
localparam device_t end_device = device_from_ascii("end");

path_count_t path_count_list[2**DEVICE_WIDTH-1:0];
logic path_count_list_is_initialized = 1'b0;

// -----------------

parameter int QUEUE_DEPTH = 8;
typedef logic [QUEUE_DEPTH-1:0] queue_ptr_t;
typedef struct packed {
    device_t device;
    path_count_t count_incr;
} update_t;

update_t update_queue[QUEUE_DEPTH-1:0];
queue_ptr_t wr_ptr = '0, rd_ptr = '0;

// -----------------

always_ff @(posedge clk) begin
    if (connection_last && device == start_device) begin: received_start_device
        update_queue[wr_ptr] <= '{start_device, 1};
        $display("update_queue PUSH {0x%03x-%s, 0x%02x}", start_device, device_to_ascii(start_device), 1);
        wr_ptr <= wr_ptr + 1;
    end
end

always_ff @(posedge clk) begin: path_count_store
    if (!path_count_list_is_initialized) begin
        path_count_list[start_device] <= 1;
        path_count_list_is_initialized <= 1'b1;
    end
end

endmodule
`default_nettype wire
