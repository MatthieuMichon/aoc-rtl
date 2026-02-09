# Day 6: Probably a Fire Hazard - Part 1

Status:

| Test                       | Status                |
|----------------------------|-----------------------|
| Reference: Python script   | :white_check_mark: Ok |
| RTL Concept: Python script | :white_check_mark: Ok |
| Simulation: Icarus Verilog | TBD |
| Simulation: Verilator      | TBD |
| Simulation: Vivado Xsim    | TBD |
| Synthesis: Vivado Zynq7    | TBD |
| On-board: Zynq7            | TBD |

# Lessons Learnt

- Python is the boss for prototyping.

# Design Space Exploration

## Reference Design

I was quite taken back by the size of working set: 1000x1000. Such a large amount of data renders any implementation relying on full parallelization unpractical on any FPGAs but the most expensive ones. With that out of the way I implemented the reference solution which is not intended for testing the implementation but rather get the correct answer.

For instance, with my custom input, the expected result is `569999`.

There is not much to write about the reference implementation, it starts with a regex for extracting the information from the input file:

```py
INPUT_REGEX = (
    r"(turn )?(?P<action>\w+) "
    r"(?P<corner0>\d+,\d+) through (?P<corner1>\d+,\d+)"
)
```

The core processing brute forces through each instruction, line and column:

```py
for instr in instructions:
    for x in range(instr["x0"], instr["x1"] + 1):
        for y in range(instr["y0"], instr["y1"] + 1):
            if "on" == instr["action"]:
                lit_lights[(x, y)] = True
            elif "off" == instr["action"]:
                lit_lights[(x, y)] = False
            elif "toggle" == instr["action"]:
                lit_lights[(x, y)] = not lit_lights.get((x, y), False)
return sum(lit_lights.values())
```

Obviously there is room for improvements but this is beside the point.

## Input Contents Properties

Circling back to the problem, I have 300 lines corresponding to *instructions* according to the problem statement. Each instruction is composed of three parts: action and two sets of two-dimensional coordinates. I added calculations to the script and came back with the following results:

- Instructions are fairly balanced in terms of action distribution.
- All the corners are sorted, with the first one using smaller coordinates for both axes.
- In total 23'163'958 *lights* were updated.
- Each instruction on average affects about 77'000 *ligths*, with min and max of respectively 4 and 798'395.

## Final Status

I also wanted to gather additional information regarding the sequence of actions, for getting a feel of the distribution of updates across the grid. Thankfully due to the *batteries included* of Python, this was quite easy by requiring just a couple of lines:

```py
LIGHT_GRID_SIZE = (1000, 1000)

def dump_lit_lights(lit_lights: dict) -> None:
    pixels_img = Image.new("1", LIGHT_GRID_SIZE, 0)
    updates_img = Image.new("RGB", LIGHT_GRID_SIZE, 0x000000)
    pixels = pixels_img.load()
    updates = updates_img.load()
    for (x, y), (is_on, depth) in lit_lights.items():
        pixels[x, y] = 1 if is_on else 0
        updates[x, y] = (
            int(depth * 255 / 300) << 16 if is_on else int(depth * 255 / 300)
        )
    pixels_img.save("lit_lights.png")
    updates_img.save("light_updates.png")
```

The final grid configuration is shown below:

![](lit_lights.png)

The following image shows the index at which each pixel was last updated (foreshadowing the FPGA implementation):

![](light_updates.png)

Yeah so this just confirmed that starting from the end makes quite a lot of sense. Altough I could brute force using the shear bandwidth of BRAM units.

## Choosing the RTL Implementation

Contrary to most previous puzzles, this one cannot be solved at line rate simply due to an amount of calculation vastly superior to the number of cycles between each instruction. Rather I see two approaches depending on the ordering of instructions used.

Beginning the processing from the start requires updating the complete grid at each instruction, the *lights* array would be accessed in a row-major order allowing for updating multiple light elements at once for much better performance.

Conversely, starting from the end allows the processing to stop updating *light* elements as soon as an instruction setting the light on or off is encountered. No further processing would be required for such *light* elements. This improved design however has two drawbacks:

- Needs for storing the per-light calculation state (known; unknown untoggled or unknown toggled)
- As the iteration goes deeper back in time, the instruction area must be masked as to not overlap known light states.

For all these reasons, I believe that the approach beginning from the start is the most practical.

## RTL Design Implementation

BRAM on Xilinx's 7-series supports a number of different port configurations, ranging from 32K single bit to 512 words of 72 bits.

| BRAM Mode | Min Instances | Total Size |
|-----------|---------------|------------|
| 32K x 1   | 1000          | 32 Mb      |
| 16K x 2   | 500           | 16 Mb      |
| 8K x 4    | 250           | 8 Mb       |
| 4K x 8    | 125           | 4 Mb       |
| 2K x 16   | 63            | 2 Mb       |
| 1K x 32   | 32            | 1 Mb       |
| 512 x 72  | 28            | ~1 Mb      |

The usecase corresponding to this puzzle is updating all 1000 bits in a single clock cycle for design complexity reasons while avoiding wasting unused bits.

Taking the extremes, the single-bit 32K deep requires 1000 instances resulting in a total of 32Mbit which worse then being extremely wasteful doesn't even fit in the Zynq-7020. Conversely, the 72-bit wide 512 deep requires a 72 bit masking operations.

I believe the sweet spot is the 1K x 32 configuration, which offers no wasted capacity and much simpler address decoding logic than the 72-bit wide configuration. The Python implementation of the FPGA logic is fairly simple. It uses a three level deep iterations:

- Iteration per-instruction
- Iteration per row
- Iteration per memory instance

```py
    for instr in instructions:
        for row in range(instr["y0"], instr["y1"] + 1):
            start_col = instr["x0"] // WORD_WIDTH
            end_col = instr["x1"] // WORD_WIDTH
            for i, ram_word in enumerate(lit_lights[row]):
                # Loop over all BRAM instances
```

The inner execution flow depdends if the current BRAM is affected or not by the instruction and in this case if so is it in an edge case or not:

```py
                if (i < start_col) or (i > end_col):
                    continue
                if i == start_col:
                    start_bit = WORD_WIDTH - 1 - (instr["x0"] % WORD_WIDTH)
                else:
                    start_bit = WORD_WIDTH - 1
                if i < end_col:
                    end_bit = 0
                else:
                    end_bit = WORD_WIDTH - 1 - (instr["x1"] % WORD_WIDTH)
```

The remainder of the inner loop is the execution of the instruction on the affected data word, which is some simple boolean logic:

```py
                # bit mask calculation, a true minefield of "off by one" errors
                bit_count = start_bit - end_bit + 1
                bit_mask = ((1 << bit_count) - 1) << end_bit
                if instr["action"] == "on":
                    lit_lights[row][i] |= bit_mask
                elif instr["action"] == "off":
                    lit_lights[row][i] &= ~bit_mask
                elif instr["action"] == "toggle":
                    lit_lights[row][i] ^= bit_mask
```

The final operation on the FPGA algorithm is the calculation of all the lit lights:

```py
    lit_light_sum = 0
    for row in lit_lights:
        for cell in row:
            lit_light_sum += cell.bit_count()
    return lit_light_sum
```

For reference, I hit a snag with the logic updating the lit lights array. It turns out that I was bit by a shallow copy mistake:

```py
# shallow copy
lit_lights = [[0x00000000] * COLS] * LIGHT_GRID_SIZE[1]

# deep copy
lit_lights = [[0x00000000] * COLS for _ in range(LIGHT_GRID_SIZE[1])]
```

Instead of trying to make sense of this situation, simply checking the `id` of two rows at difference index would have indicated my obvious mistake:

```py
id(lit_lights[0])
139884236147648
id(lit_lights[1])
139884236147648
```

Having fixed this issue, I obtain perfect results:

```
Result: 569999
FPGA-style impl result: 569999
```

# RTL Implementation

## First Iteration: Input Normalization

This step was overglossed in the Python implementation but is essential non the less.

Instructions impacting a very large number of elements (several dozens of thousands or more) cannot be handled before the following instruction lands. The only way around this is to store all the instructions in a buffer while instructions are processed.

Sizing the memory is the obvious first step. Each instruction contains the following fields:

- `action`: The requested operation
  - One out of three choices (`turn on`, `turn off`, or `toggle`)
- `start_row`: The starting row of the instruction
  - A decimal number in ASCII from one to three digits long
- `start_col`: The starting column of the instruction
  - A decimal number in ASCII from one to three digits long
- `end_row`: The ending row of the instruction
  - A decimal number in ASCII from one to three digits long
- `end_col`: The ending column of the instruction
  - A decimal number in ASCII from one to three digits long

The exact formatting of the input is as follows:

```
<action> <start_row>,<start_col> thorugh <end_row>,<end_col>
```

The decoding of the action is simple since it requires matching a sequence of two characters:

- turn **on** yields `0b11`
- turn **of**f yields `0b00`
- **to**ggle yields `0b10`

| Action   | Binary |
|----------|--------|
| turn on  | `0b11` |
| turn off | `0b00` |
| toggle   | `0b10` |

For the next step, there is nothing imposing the order between rows and columns. I decided to go with the row as major order since the implementation iterates over rows first.

The ASCII number to binary conversion reuses the work done in past puzzles so nothing new here. The main difference is that four binary values must be presented on the output interface.

| Output Value | Bits |
|--------------|------|
| Last         |  1   |
| Valid        |  1   |
| Action       |  2   |
| Start Row    | 12   |
| Start Col    | 12   |
| End Row      | 12   |
| End Col      | 12   |

> [!NOTE]
> Although position values could fit using 10 bits, I increased their width to 12 bits for improved QoL, as using multiples of four makes inspection of the generated values much easier. The following step with regards to memory usage is located at 72 bits, thus there are no real downsides using a couple more bits.

The schematic of the line decoder is quite busy:

![Line Decoder Schematic](line_decoder_yosys.png)

Vivado provides the following break-down. Although there are quite a lot going on, nothing stands out:

```
Module line_decoder 
Detailed RTL Component Info : 
+---Adders : 
	   3 Input   12 Bit       Adders := 1     
	   2 Input   12 Bit       Adders := 1     
+---Registers : 
	               12 Bit    Registers := 5     
	                8 Bit    Registers := 1     
	                2 Bit    Registers := 1     
	                1 Bit    Registers := 2     
+---Multipliers : 
	               4x12  Multipliers := 1     
+---Muxes : 
	   2 Input   12 Bit        Muxes := 1     
	   2 Input    2 Bit        Muxes := 4     
	   4 Input    2 Bit        Muxes := 2     
	   2 Input    1 Bit        Muxes := 5     
	   3 Input    1 Bit        Muxes := 2     
	   4 Input    1 Bit        Muxes := 4     
```

I'm also provisionning two extra bits for storing a delayed signal signifiying the entry is valid and an other informing signifying the last entry. The delayed signal greatly simplifies the implementation of a dual clock design which I believe is likely to be required.

The puzzle asks for the number of lit lights out of a 1000x1000 grid. The worst case answer being greater then 2^16 but smaller then 2^24, thus the result width is set to 24.

### Design Components

| Module                                          | Description                      | Complexity          | Thoughts       | Remarks  |
|-------------------------------------------------|----------------------------------|---------------------|----------------|----------|
| [`user_logic_tb`](user_logic_tb.sv)             | Testbench                        | :large_blue_circle: | :kissing_smiling_eyes: Copy-paste from previous puzzle | |
| [`user_logic`](user_logic.sv)                   | Logic top-level                  | :large_blue_circle: | :kissing_smiling_eyes: Wire harness and trivial logic | Had to change reset logic |
| [`tap_decoder`](tap_decoder.sv)                 | JTAG TAP deserializer            | :large_blue_circle: | :kissing_smiling_eyes: Copy-paste from previous puzzle | |
| [`line_decoder`](line_decoder.sv)               | Converts into instruction array  | :green_circle:      | :slightly_smiling_face: Several moving parts | Multiple fields to decode and keep track of |
| [`tap_encoder`](tap_encoder.sv)                 | JTAG TAP serializer              | :large_blue_circle: | :kissing_smiling_eyes: Copy-paste from previous puzzle | |

### Resource Usage

The user logic module contains a `$countones` applied to the instruction array data to avoid it being pruned during optimization. This is refleted in the by module breakdown.

|      Instance      |    Module    | Total LUTs | Logic LUTs | LUTRAMs | SRLs | FFs | RAMB36 | RAMB18 | DSP Blocks |
|--------------------|--------------|------------|------------|---------|------|-----|--------|--------|------------|
| shell              |        (top) |        147 |        147 |       0 |    0 | 160 |      0 |      0 |          0 |
|   (shell)          |        (top) |          0 |          0 |       0 |    0 |   0 |      0 |      0 |          0 |
|   user_logic_i     |   user_logic |        147 |        147 |       0 |    0 | 160 |      0 |      0 |          0 |
|     (user_logic_i) |   user_logic |         74 |         74 |       0 |    0 |  25 |      0 |      0 |          0 |
|     line_decoder_i | line_decoder |         53 |         53 |       0 |    0 |  74 |      0 |      0 |          0 |
|     tap_decoder_i  |  tap_decoder |          7 |          7 |       0 |    0 |  13 |      0 |      0 |          0 |
|     tap_encoder_i  |  tap_encoder |         13 |         13 |       0 |    0 |  48 |      0 |      0 |          0 |

| Ref Name | Used | Functional Category |
|----------|------|---------------------|
| FDRE     |  160 |        Flop & Latch |
| LUT3     |   77 |                 LUT |
| LUT6     |   41 |                 LUT |
| LUT2     |   31 |                 LUT |
| LUT5     |   30 |                 LUT |
| CARRY4   |   30 |          CarryLogic |
| LUT4     |   16 |                 LUT |
| BUFG     |    1 |               Clock |
| BSCANE2  |    1 |              Others |

## Second Iteration: Instruction Buffer

Instructions are received every 184 to 272 TCK clock cycles, depending on their length. The rate at which the downstream logic is able to process these instructions depends on the number of rows affected by each instruction and the request operation and can vary across three orders of magnitude, exceeding 1000 clock cycles. Thus, even using a faster clock the downstream is not guaranteed to keep up with the inbound instruction rate. An instruction buffer is therefore mandatory.
