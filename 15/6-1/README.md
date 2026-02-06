# Day 6: Probably a Fire Hazard - Part 1

Status:

| Test                       | Status                |
|----------------------------|-----------------------|
| Reference: Python script   | :white_check_mark: Ok |
| RTL Concept: Python script | TBD |
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

BRAM on Xilinx's 7-series support different port configurations, from 32K single bit to 512 words of 72 bits.

| BRAM Mode | Max Simultaneous Updates |
|-----------|--------------------------|
| 32K x 1   | 31                       |
| 16K x 2   | 62                       |
| 8K x 4    | 124                      |
| 4K x 8    | 248                      |
| 2K x 16   | 496                      |
| 1K x 32   | 992                      |
| 512 x 72  | 1984                     |

The most efficient configurations are the two with the largest data width, however the 72-bit wide data requires quite more muxing logic for implementing bit-masking operations. This leaves me with the 1K x 32 configuration. Reflecting this choice in the Python script requires using a two-dimensional array containing cells of 32 bits, the last cell having its LSB bits unused.

I hit a snag with the logic updating the lit lights array. It turns out that I was bit by a shallow copy mistake:

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
