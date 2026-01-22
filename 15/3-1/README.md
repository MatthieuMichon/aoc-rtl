# Day 3: Perfectly Spherical Houses in a Vacuum - Part 1

Things are getting started!

Status:

| Test                       | Status                |
|----------------------------|-----------------------|
| Simulation: Icarus Verilog | :white_check_mark: Ok |
| Simulation: Verilator      | :white_check_mark: Ok |
| Simulation: Vivado Xsim    | :white_check_mark: Ok |
| Synthesis: Vivado Zynq7    | :white_check_mark: Ok |
| On-board: Zynq7            | :white_check_mark: Ok |

# Lessons Learnt

- Slapping a logic analyzer (ILA) is surprisingly easy, just a couple of lines of TCL and Verilog, and effective for gathering insights on device primitives behavior.

# Design Space Exploration

So, let's talk about the *infinite two-dimensional grid*, at a first glance there are 8192 (triggered the power of two decimal detection part in my brain) moves. This total is a reasonable amount speaking in terms of FPGA memory.

Obviously the FPGA will get nowhere running an algorithm with a $$\mathcal{O}(n^2)$$ time complexity. Thus before thinking of coding, a look at the pattern followed by the successive moves would be useful first step.

```
Direction (0, 1): 2070 moves
Direction (1, 0): 2027 moves
Direction (-1, 0): 2092 moves
Direction (0, -1): 2003 moves
Final rest X: -65
Final rest Y: 67
Min X: -72
Min Y: -3
Max X: 27
Max Y: 73
```

All the moves can be boxed using coordinates between -128 and 127, resulting in a 32K address space. Since a single bit is sufficient for representing the visited status, all I need is a single 36K BRAM. Obviously this puzzle could have been a tad more complex if the amplitude of the walk was larger.

Counting the visited houses is just a question of incrementing a counter when an empty house is encountered.

# Implementation

## First Iteration

Simply counting the number of moves would be an interesting intermediate step, as the expected number of already known.

Due to the small number of combinations, I was thinking of using a one-hot encoding where each direction is represented by a single dedicated bit. This makes the `line_decoder` module trivial to implement.

### Improved JTAG Data Serialization

A sore point of my previous implementations was the relatively slow data transfer rate. This was primarily due to serializing data on a per byte basis. Removing this per byte serialization and going straight for continuously streaming the whole inputs contents should yield a significant improvement.

The overhead of handling each byte separately is significant, as the JTAG TAP state machine must go through five states every byte. This increases the number of required `tck` cycles by 62.5 %. In practice this overhead is even higher on-board due to additional TCL commands required for transitioning between states.

#### Simulation Testbench Changes

Following the creation of a small [proof-of-concept project](https://github.com/MatthieuMichon/bscan-waves) for producing real waveforms of the BSCANE2 outputs. I decided to completely overhaul the implementation of the BSCANE2 emulation in the main simulation testbench:

- Added states related to the IR shift register
- Addition of the `tms` signal with the proper values reflecting the TAP state machine transitions
- Correctly emulating the initialization of the BSCANE2 module with the proper IR value
- Continuous streaming of input contents bytes

#### Vivado TCL Script Changes

My first priority is getting the testbench to match as closely as possible the actual behavior of Xilinx's BSCANE2 primitive. I added a very deep ILA probe (128K samples) and embarked on a journey to capture the relevant events. The first one being the selection of the correct IR value.

Due to the ILA and the user logic sharing the JTAG interface, I followed this sequence for capturing the data:

- Program firmware and load probe file
- Setup a trigger for rising edge of `SEL` (`ir_is_user` in my design)
- Close the hardware manager
- Open the hardware manager in JTAG mode
- Execute the `scan_ir_hw_jtag` command with the relevant IR value
- Close the hardware manager
- Open the hardware manager in the ILA GUI
- Download the ILA capture

```tcl
# Vivado TCL console invoked using `vivado -mode tcl`
open_hw_manager
connect_hw_server
open_hw_target -jtag_mode on
set zynq7_ir_length 10
set zynq7_ir_user4 0x3e3
run_state_hw_jtag RESET
run_state_hw_jtag IDLE
scan_ir_hw_jtag $zynq7_ir_length -tdi $zynq7_ir_user4
close_hw_target
```

![](tap_sel_ila_capture.png)

The second step is to ensure that the improved deserialization process behaves as expected. I opted for an incremental approach, starting with a single block of data with zero padding. I chose the at sign `@` due to its ASCII value of 0x40 making it easy to distinguish during the bit shifting operations.

While testing I discovered that the first `tdi` value received once in *SHIFT_DR* state is invalid. This is due to the JTAG TAP being downstream of the ARM DAP controller, which in *BYPASS* mode behaves as a single bit register.

For ensuring proper reusability, I decided to add a parameter `UPSTREAM_BYPASS_BITS` to the module.

```diff
module tap_decoder #(
    parameter int INBOUND_DATA_WIDTH,
+    parameter int UPSTREAM_BYPASS_BITS
)(
    // JTAG TAP Controller Signals
        input wire tck,
        input wire tms,
        input wire tdi,
        input wire test_logic_reset,
        input wire ir_is_user,
        input wire shift_dr,
        input wire update_dr,
    // Deserialized Data
        output logic inbound_alignment_error,
        output logic inbound_valid,
        output logic [INBOUND_DATA_WIDTH-1:0] inbound_data
);
```

```tcl
# Vivado TCL console invoked using `vivado -mode tcl`
open_hw_manager
connect_hw_server
open_hw_target -jtag_mode on
set zynq7_ir_length 10
set zynq7_ir_user4 0x3e3
run_state_hw_jtag RESET
run_state_hw_jtag IDLE
scan_ir_hw_jtag $zynq7_ir_length -tdi $zynq7_ir_user4
scan_dr_hw_jtag 129 -tdi 0x0a404040404040404040404040404040; # byte swapped
close_hw_target
```

![](tap_load_chunk_ila_capture.png)

The serialization process in the Vivado script `vivado.tcl` was completely revamped with the division of the file contents into blocks performed in a dedicated function `load_blocks`, and the per-block serialization process handled in the main loop of the input loading function `load_inputs`.

My initial thoughts on this matter were to use 16 byte blocks for serialization and pad the remaining bytes with null bytes. For a typical 12 kbyte input length, this implementation would cut down by 16 the number of individual TCL commands. A thing I nearly forgot was that JTAG uses a LSB-first encoding, thus the bytes in each block should be reversed prior to serialization (this process could not be implemented in the FPGA since this would require knowing in advance the number of bytes to be padded in the last block).

These changes mean breaking quite a lot of things in the TCL script, as it was operating on a per-line then per-byte basis. I changed the text file loading procedure to use blocks of N bytes instead of lines of text.

Using chunks of data instead of lines of text requires changing the translation type from the default (text) to binary.

```diff
-   set fhandle [open $file]
+   set fhandle [open $file rb]
```

Instead of looping over each line, the whole file is read in a single operation.

```diff
-while {[gets $fhandle line]>=0} {
-    lappend lines $line
-}
+set data [read $fhandle]
```

Padding length is calculated by subtracting the block size by the number of bytes sticking out after the last complete block. A modulo operation to the block size is applied to this value for handling cases where the file ends on a block boundary.

$$Padding(x)=(BlockSize-(x\%BlockSize))\%BlockSize$$

```tcl
set file_len [string length $data]
set delta_len [expr {$block_size - ($file_len % $block_size)}]
set padding_len [expr {$delta_len % $block_size}]
append data [string repeat \x00 $padding_len]
```

Iterating is done per chunk of the block size instead over each line, and following the required padding, finally the whole chunk is byte swap to comply with the JTAG protocol.

```tcl
if {$swap_bytes} {
    set hex [join [lreverse [regexp -all -inline .. $hex]] ""]
}
```

Furthermore, I was thinking of doing without having to go through the UPDATE state of the JTAG TAP controller. The documentation of the `scan_dr_hw_jtag` in the TCL command reference user-guide (ug835) calls out a method for doing so:

> To break up a long data register shift into multiple SDR shifts, specify an end_state of DRPAUSE. This will cause the first `scan_dr_hw_jtag` command to end in the DRPAUSE stable state, and then the subsequent scan_dr_hw_jtag commands will go to DREXIT2 state before going back to DRSHIFT.

### Design Components

| Module                                          | Description                      | Complexity          | Thoughts       | Remarks  |
|-------------------------------------------------|----------------------------------|---------------------|----------------|----------|
| [`user_logic_tb`](user_logic_tb.sv)             | Testbench                        | :yellow_circle:     | :expressionless: Copy-paste from previous puzzle | Overhauled JTAG serialization|
| [`user_logic`](user_logic.sv)                   | Logic top-level                  | :large_blue_circle: | :kissing_smiling_eyes: Wire harness and trivial logic | |
| [`tap_decoder`](tap_decoder.sv)                 | JTAG TAP deserializer            | :green_circle:      | :slightly_smiling_face: Add proper handling of upstream bypass bits | |
| [`tap_encoder`](tap_encoder.sv)                 | JTAG TAP serializer              | :large_blue_circle: | :kissing_smiling_eyes: Copy-paste from previous puzzle | |

### Run Times

Full simulation: compilation and runtime (low-spec laptop):

| Run Times | Icarus Verilog | Verilator | Vivado Xsim | Vivado FPGA Build |
|-----------|----------------|-----------|-------------|-------------------|
| Real      | 0.822s         | 4.432s    | 10.182s     | 2m3.612s          |
| User      | 0.787s         | 12.464s   | 10.046s     | 2m9.192s          |
| Sys       | 0.032s         | 0.768s    | 0.986s      | 0m6.701s          |

## Second Iteration

In this next step I will simply add the logic required for tracking the position, with a first module converting the received ASCII character into one of four possible moves, followed by a a bank of accumulators for both positions (X and Y).

Lastly the visited positions are tracked by module aptly named `visited_positions` which is nothing more than a simple-port RAM running in the read-before-write mode.

### Further Improved JTAG Data Serialization

The implementation of the data serialization has a major limitation, in that the testbench and Vivado TCL script do not behave identically. Although this wouldn't matter for simple designs such as this one, for more complex designs where the timings between process modules, these changes in the timing of data arrival may result in different behavior causing unexpected behavior being more difficult to reproduce and debug.

According to common knowledge as presented by major LLMs, the TCL interpreter is efficient at string and binary manipulation, meaning that it can handle the byte swapping of the complete hex-string data from reading the input contents.

### Design Components

| Module                                          | Description                      | Complexity          | Thoughts       | Remarks  |
|-------------------------------------------------|----------------------------------|---------------------|----------------|----------|
| [`user_logic_tb`](user_logic_tb.sv)             | Testbench                        | :yellow_circle:     | :expressionless: Copy-paste from previous puzzle | Overhauled JTAG serialization|
| [`user_logic`](user_logic.sv)                   | Logic top-level                  | :large_blue_circle: | :kissing_smiling_eyes: Wire harness and trivial logic | |
| [`position_tracker`](position_tracker.sv)       | Keeps track of the coordinates   | :large_blue_circle: | :kissing_smiling_eyes: Very simple logic | |
| [`visited_position`](visited_position.sv)       | Tag all visited positions        | :large_blue_circle: | :kissing_smiling_eyes: Very simple logic | |
| [`tap_decoder`](tap_decoder.sv)                 | JTAG TAP deserializer            | :green_circle:      | :slightly_smiling_face: Add proper handling of upstream bypass bits | |
| [`tap_encoder`](tap_encoder.sv)                 | JTAG TAP serializer              | :large_blue_circle: | :kissing_smiling_eyes: Copy-paste from previous puzzle | |

### Resource Usage

|         Instance        |       Module      | Total LUTs | Logic LUTs | LUTRAMs | SRLs | FFs | RAMB36 | RAMB18 | DSP Blocks |
|-------------------------|-------------------|------------|------------|---------|------|-----|--------|--------|------------|
| shell                   |             (top) |         59 |         59 |       0 |    0 | 115 |      2 |      0 |          0 |

| Ref Name | Used | Functional Category |
|----------|------|---------------------|
| FDRE     |  115 |        Flop & Latch |
| LUT2     |   35 |                 LUT |
| CARRY4   |   24 |          CarryLogic |
| LUT3     |   16 |                 LUT |
| LUT5     |    9 |                 LUT |
| LUT1     |    8 |                 LUT |
| LUT6     |    3 |                 LUT |
| RAMB36E1 |    2 |        Block Memory |
| LUT4     |    2 |                 LUT |
| BUFG     |    1 |               Clock |
| BSCANE2  |    1 |              Others |

As intended, the RAM is a simple-port:

| Memory Name                                           | Array Size | RAM_STYLE | Memory Type | Port 1 Dimension / Map | Port 2 Dimension / Map |
|-------------------------------------------------------|------------|-----------|-------------|------------------------|------------------------|
| user_logic_i/visited_positions_i/visited_table        |      65536 |           | RAM_SP      | 65536x1                |                        |
|  user_logic_i/visited_positions_i/visited_table_reg_0 |      32768 |      AUTO |             |  A:A:32768x1           |                        |
|  user_logic_i/visited_positions_i/visited_table_reg_1 |      32768 |      AUTO |             |  A:A:32768x1           |                        |

I was intrigued by the relative high usage of LUT2 primitives and decided to dig deeper into the design using the following snippet:

```tcl
puts  "| LUT2 Cell | I0 | I1 | O |"
puts  "|---|---|---|---|"
foreach lut2_cell [get_cells -hierarchical -filter {REF_NAME == LUT2}] {
    set neighbors {}
    foreach pin_name {I0 I1 O} {
        set pin [get_pins $lut2_cell/$pin_name]
        set net [get_nets -of_objects $pin]
        set opposite_cell [get_property REF_NAME [lindex [get_cells -of_objects $net -filter "NAME != $lut2_cell"] 0]]
        lappend neighbors "$opposite_cell: $net"
    }
    puts [format "| %s | %s | %s | %s |" \
          [file tail $lut2_cell] [lindex $neighbors 0] [lindex $neighbors 1] [lindex $neighbors 2]]
}
```

| LUT2 Cell | I0 | I1 | O |
|---|---|---|---|
| visited_houses[0]_i_1 | visited_positions: user_logic_i/lookup_valid | visited_positions: user_logic_i/lookup_already_visited | FDRE: user_logic_i/visited_houses[0] |
| pos_x[3]_i_3 | CARRY4: user_logic_i/position_tracker_i/pos_x[2] | CARRY4: user_logic_i/position_tracker_i/pos_x[3] | CARRY4: user_logic_i/position_tracker_i/pos_x[3]_i_3_n_0 |
| pos_x[3]_i_4 | CARRY4: user_logic_i/position_tracker_i/pos_x[1] | CARRY4: user_logic_i/position_tracker_i/pos_x[2] | CARRY4: user_logic_i/position_tracker_i/pos_x[3]_i_4_n_0 |
| pos_x[3]_i_5 | CARRY4: user_logic_i/position_tracker_i/pos_x[1] | LUT5: user_logic_i/position_tracker_i/shift_direction[2] | CARRY4: user_logic_i/position_tracker_i/pos_x[3]_i_5_n_0 |
| pos_x[7]_i_3 | LUT2: user_logic_i/position_tracker_i/pos_x[6] | FDRE: user_logic_i/position_tracker_i/pos_x[7] | CARRY4: user_logic_i/position_tracker_i/pos_x[7]_i_3_n_0 |
| pos_x[7]_i_4 | CARRY4: user_logic_i/position_tracker_i/pos_x[5] | LUT2: user_logic_i/position_tracker_i/pos_x[6] | CARRY4: user_logic_i/position_tracker_i/pos_x[7]_i_4_n_0 |
| pos_x[7]_i_5 | CARRY4: user_logic_i/position_tracker_i/pos_x[4] | CARRY4: user_logic_i/position_tracker_i/pos_x[5] | CARRY4: user_logic_i/position_tracker_i/pos_x[7]_i_5_n_0 |
| pos_x[7]_i_6 | CARRY4: user_logic_i/position_tracker_i/pos_x[3] | CARRY4: user_logic_i/position_tracker_i/pos_x[4] | CARRY4: user_logic_i/position_tracker_i/pos_x[7]_i_6_n_0 |
| pos_y[3]_i_3 | CARRY4: user_logic_i/position_tracker_i/pos_y[2] | CARRY4: user_logic_i/position_tracker_i/pos_y[3] | CARRY4: user_logic_i/position_tracker_i/pos_y[3]_i_3_n_0 |
| pos_y[3]_i_4 | CARRY4: user_logic_i/position_tracker_i/pos_y[1] | CARRY4: user_logic_i/position_tracker_i/pos_y[2] | CARRY4: user_logic_i/position_tracker_i/pos_y[3]_i_4_n_0 |
| pos_y[3]_i_5 | CARRY4: user_logic_i/position_tracker_i/pos_y[1] | LUT5: user_logic_i/position_tracker_i/shift_direction[3] | CARRY4: user_logic_i/position_tracker_i/pos_y[3]_i_5_n_0 |
| pos_y[7]_i_3 | LUT2: user_logic_i/position_tracker_i/pos_y[6] | FDRE: user_logic_i/position_tracker_i/pos_y[7] | CARRY4: user_logic_i/position_tracker_i/pos_y[7]_i_3_n_0 |
| pos_y[7]_i_4 | CARRY4: user_logic_i/position_tracker_i/pos_y[5] | LUT2: user_logic_i/position_tracker_i/pos_y[6] | CARRY4: user_logic_i/position_tracker_i/pos_y[7]_i_4_n_0 |
| pos_y[7]_i_5 | CARRY4: user_logic_i/position_tracker_i/pos_y[4] | CARRY4: user_logic_i/position_tracker_i/pos_y[5] | CARRY4: user_logic_i/position_tracker_i/pos_y[7]_i_5_n_0 |
| pos_y[7]_i_6 | CARRY4: user_logic_i/position_tracker_i/pos_y[3] | CARRY4: user_logic_i/position_tracker_i/pos_y[4] | CARRY4: user_logic_i/position_tracker_i/pos_y[7]_i_6_n_0 |
| inbound_data[7]_i_1 | LUT4: user_logic_i/tap_decoder_i/test_logic_reset | LUT5: user_logic_i/tap_decoder_i/shift_dr | FDRE: user_logic_i/tap_decoder_i/reset_condition |
| inbound_valid_i_10 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[23]_i_1_n_7 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[23]_i_1_n_6 | CARRY4: user_logic_i/tap_decoder_i/inbound_valid_i_10_n_0 |
| inbound_valid_i_11 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[19]_i_1_n_5 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[19]_i_1_n_4 | CARRY4: user_logic_i/tap_decoder_i/inbound_valid_i_11_n_0 |
| inbound_valid_i_12 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[19]_i_1_n_7 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[19]_i_1_n_6 | CARRY4: user_logic_i/tap_decoder_i/inbound_valid_i_12_n_0 |
| inbound_valid_i_14 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[15]_i_1_n_5 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[15]_i_1_n_4 | CARRY4: user_logic_i/tap_decoder_i/inbound_valid_i_14_n_0 |
| inbound_valid_i_15 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[15]_i_1_n_7 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[15]_i_1_n_6 | CARRY4: user_logic_i/tap_decoder_i/inbound_valid_i_15_n_0 |
| inbound_valid_i_16 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[11]_i_1_n_5 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[11]_i_1_n_4 | CARRY4: user_logic_i/tap_decoder_i/inbound_valid_i_16_n_0 |
| inbound_valid_i_17 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[11]_i_1_n_7 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[11]_i_1_n_6 | CARRY4: user_logic_i/tap_decoder_i/inbound_valid_i_17_n_0 |
| inbound_valid_i_19 | LUT2: user_logic_i/tap_decoder_i/shift_count_reg[3]_i_1_n_7 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[3]_i_1_n_6 | CARRY4: user_logic_i/tap_decoder_i/inbound_valid_i_19_n_0 |
| inbound_valid_i_20 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[7]_i_1_n_5 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[7]_i_1_n_4 | CARRY4: user_logic_i/tap_decoder_i/inbound_valid_i_20_n_0 |
| inbound_valid_i_21 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[7]_i_1_n_7 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[7]_i_1_n_6 | CARRY4: user_logic_i/tap_decoder_i/inbound_valid_i_21_n_0 |
| inbound_valid_i_22 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[3]_i_1_n_4 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[3]_i_1_n_5 | CARRY4: user_logic_i/tap_decoder_i/inbound_valid_i_22_n_0 |
| inbound_valid_i_23 | LUT2: user_logic_i/tap_decoder_i/shift_count_reg[3]_i_1_n_7 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[3]_i_1_n_6 | CARRY4: user_logic_i/tap_decoder_i/inbound_valid_i_23_n_0 |
| inbound_valid_i_4 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[31]_i_2_n_5 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[31]_i_2_n_4 | CARRY4: user_logic_i/tap_decoder_i/inbound_valid_i_4_n_0 |
| inbound_valid_i_5 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[31]_i_2_n_7 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[31]_i_2_n_6 | CARRY4: user_logic_i/tap_decoder_i/inbound_valid_i_5_n_0 |
| inbound_valid_i_6 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[27]_i_1_n_5 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[27]_i_1_n_4 | CARRY4: user_logic_i/tap_decoder_i/inbound_valid_i_6_n_0 |
| inbound_valid_i_7 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[27]_i_1_n_7 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[27]_i_1_n_6 | CARRY4: user_logic_i/tap_decoder_i/inbound_valid_i_7_n_0 |
| inbound_valid_i_9 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[23]_i_1_n_5 | FDRE: user_logic_i/tap_decoder_i/shift_count_reg[23]_i_1_n_4 | CARRY4: user_logic_i/tap_decoder_i/inbound_valid_i_9_n_0 |
| shift_reg[15]_i_1 | LUT3: user_logic_i/tap_encoder_i/capture_dr | FDRE: user_logic_i/tap_encoder_i/data_r[15] | FDRE: user_logic_i/tap_encoder_i/shift_reg[15]_i_1_n_0 |
| ram_rd_valid_i_1 | RAMB36E1: user_logic_i/visited_positions_i/pos_change | FDRE: user_logic_i/visited_positions_i/reset | FDRE: user_logic_i/visited_positions_i/ram_rd_valid_i_1_n_0 |

According to these results, the vast majority of the LUT2 are used as propagate logic for the CARRY4 chains.
