# Day 6: Probably a Fire Hazard - Part 2

Status:

| Test                       | Status                |
|----------------------------|-----------------------|
| Reference: Python script   | *To be done* |
| RTL Concept: Python script | *To be done* |
| Simulation: Icarus Verilog | *To be done* |
| Simulation: Verilator      | *To be done* |
| Simulation: Vivado Xsim    | *To be done* |
| Synthesis: Vivado Zynq7    | *To be done* |
| On-board: Zynq7            | *To be done* |

# Lessons Learnt

- *To be done*

# Design Space Exploration

## Reference Design

The second part changes the instruction semantics:

| Instruction | Part One | Part Two   |
|-------------|----------|------------|
| on          | 1        | +1         |
| off         | 0        | max(0, -1) |
| toggle      | xor 1    | +2         |

The obvious question is the maximum value obtained during the course of the processing. This value as direct impact on the required FPGA memory usage and may require using a different approach for reducing memory usage at the cost of increase time.

The change to the reference design is straightforward, the following snippet shows how the new value is calculated and also how the peak value is kept track of:

```py
old_value = lit_lights.get((x, y), [0, 0])[0]
if "on" == instr["action"]:
    new_value = old_value + 1
    lit_lights[(x, y)] = [new_value, new_value]
elif "off" == instr["action"]:
    new_value = max(old_value - 1, 0)
    lit_lights[(x, y)] = [new_value, old_value]
elif "toggle" == instr["action"]:
    new_value = old_value + 2
    lit_lights[(x, y)] = [new_value, new_value]
```

Mapping the final and peak intensities yields interesting pictures:

![](lights_intensity.png)

![](max_lights_intensity.png)

For my custom input, I obtain a peak value across all the the lights of `49`. Right of the bat, this results in a six fold ($$\lceil\log_2(49)\rceil=6$$) memory requirement increase if the same implementation is required. Based on the resource usage of the previous implementation this requires 193 BRAM instances.

The main challenge is the computing of per light changes which are now much more resource heavy due to the simple bitmask operations being replaced by 6-bit arithemetics and a max operation.

Instead of 32 instances of 32x1000 storage elements, an optimized storage strategy would keep the 1000-deep elements but use 36 bits devided in 6 lights with 6-bit worth of intensity. Doing so requires 167 BRAM instances which is slightly less than figure from above thanks to using the extra bits (36 instead of 32).
