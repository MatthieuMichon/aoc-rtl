# Day 5: Doesn't He Have Intern-Elves For This? - Part 1

Status:

| Test                       | Status                |
|----------------------------|-----------------------|
| Reference: Python script   | :white_check_mark: Ok |
| Simulation: Icarus Verilog | :white_check_mark: Ok |
| Simulation: Verilator      | :white_check_mark: Ok |
| Simulation: Vivado Xsim    | :white_check_mark: Ok |
| Synthesis: Vivado Zynq7    | :white_check_mark: Ok |
| On-board: Zynq7            | :white_check_mark: Ok |

# Lessons Learnt

- Review and challenge the resource usage figures, there is more likely than not some low-hanging fruit to be found.

# Design Space Exploration

The Python script acting as a reference implementation for this puzzle is quite simple, the only idiom worth mentioning being the sliding window using transpose function `zip`:

```py
sliding_window = zip(string, string[1:])
```

The number of lines is exactly 1000 which is par for the course for multi-lines puzzle inputs.

# Implementation

The input contents for this puzzle are letters, meaning that each character requires five bits instead of four for numbers. Each line being exactly 16 characters long and independent of each others, the storage required is 80 bits which is not a concern. Furthermore as each character is serialized, the design should have no trouble running at the input rate.

## First Iteration: Basic Content Decoding

Due to very little processing being required there is absolutely no need to use a dual-clock implementation as the one used in the previous puzzle (4.2). Instead I'm simply rolling back to the standard single-clock implementation.

I added a trivial implementation of the string filter module and logic for counting the number of strings which passed by.

### Resource Usage

Unsurprisingly, logic resource usage is minimal.

|      Instance       |     Module    | Total LUTs | Logic LUTs | LUTRAMs | SRLs | FFs |
|---------------------|---------------|------------|------------|---------|------|-----|
| shell               |         (top) |         37 |         37 |       0 |    0 |  92 |
|   (shell)           |         (top) |          0 |          0 |       0 |    0 |   0 |
|   user_logic_i      |    user_logic |         37 |         37 |       0 |    0 |  92 |
|     (user_logic_i)  |    user_logic |          3 |          3 |       0 |    0 |  17 |
|     string_filter_i | string_filter |          4 |          4 |       0 |    0 |   2 |
|     tap_decoder_i   |   tap_decoder |         21 |         21 |       0 |    0 |  41 |
|     tap_encoder_i   |   tap_encoder |          9 |          9 |       0 |    0 |  32 |

## Second Iteration: String Filter Rules Check

I have opted to break down the three conditions into independent processes cleared after each newline (LF char). Combining these signals is done in a final process with the following source code:

```verilog
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
```

### Final Resource Usage

The synthesizer has come up with the following resource usage:

```
Detailed RTL Component Info : 
+---Adders : 
	   2 Input   32 Bit       Adders := 1     
	   2 Input    4 Bit       Adders := 1     
+---Registers : 
	               32 Bit    Registers := 1     
	               16 Bit    Registers := 2     
	                8 Bit    Registers := 2     
	                4 Bit    Registers := 1     
	                1 Bit    Registers := 7     
+---Muxes : 
	   4 Input   32 Bit        Muxes := 1     
	   2 Input   16 Bit        Muxes := 1     
	   2 Input    4 Bit        Muxes := 1     
	   3 Input    4 Bit        Muxes := 1     
	   2 Input    3 Bit        Muxes := 1     
	   2 Input    2 Bit        Muxes := 1     
	   2 Input    1 Bit        Muxes := 10    
	   3 Input    1 Bit        Muxes := 4     
```

I was puzzled by the 32-bit adder. Digging deeper I explicitly sized a counter located in the TAP decoder module (`shift_count`) and this reduced the usage quite a bit: from 46 and 106 downto 42 and 78 for respectively LUTs and FFs.

|       Instance      |     Module    | Total LUTs | Logic LUTs | LUTRAMs | SRLs | FFs |
|---------------------|---------------|------------|------------|---------|------|-----|
| shell               |         (top) |         42 |         42 |       0 |    0 |  78 |
|   (shell)           |         (top) |          0 |          0 |       0 |    0 |   0 |
|   user_logic_i      |    user_logic |         42 |         42 |       0 |    0 |  78 |
|     (user_logic_i)  |    user_logic |          3 |          3 |       0 |    0 |  17 |
|     string_filter_i | string_filter |         23 |         23 |       0 |    0 |  16 |
|     tap_decoder_i   |   tap_decoder |          7 |          7 |       0 |    0 |  13 |
|     tap_encoder_i   |   tap_encoder |          9 |          9 |       0 |    0 |  32 |
