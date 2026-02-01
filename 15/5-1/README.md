# Day 5: Doesn't He Have Intern-Elves For This? - Part 1

Status:

| Test                       | Status                |
|----------------------------|-----------------------|
| Reference: Python script   | :white_check_mark: Ok |
| Simulation: Icarus Verilog | TBD |
| Simulation: Verilator      | TBD |
| Simulation: Vivado Xsim    | TBD |
| Synthesis: Vivado Zynq7    | TBD |
| On-board: Zynq7            | TBD |

# Lessons Learnt

- TBD

# Design Space Exploration

The Python script acting as a reference implementation for this puzzle is quite simple, the only idiom worth mentioning being the sliding window using transpose function `zip`:

```py
sliding_window = zip(string, string[1:])
```

The number of lines is exactly 1000 which is par for the course for multi-lines puzzle inputs.

# Implementation

The input contents for this puzzle are letters, meaning that each character requires five bits instead of four for numbers. Each line being exactly 16 characters long and independent of each others, the storage required is 80 bits which is not a concern. Furthermore as each character is serialized, the design should have no trouble running at the input rate.
