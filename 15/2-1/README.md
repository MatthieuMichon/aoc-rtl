# 2015 Day 2: I Was Told There Would Be No Math - Part 1

FIXME__BRIEF_DESCRIPTION

Status:

| Test                       | Status                |
|----------------------------|-----------------------|
| Simulation: Icarus Verilog | *Not tested*          |
| Simulation: Verilator      | *Not tested*          |
| Simulation: Vivado Xsim    | *Not tested*          |
| Synthesis: Vivado Zynq7    | *Not tested*          |
| On-board: Zynq7            | *Not tested*          |

# Lessons Learnt

- *To be completed*

# Puzzle Statement

> - A list of the dimensions (length l, width w, and height h).
> - Find the surface area of the box, which is 2*l*w + 2*w*h + 2*h*l.
> - extra paper for each present: the area of the smallest side.

My initial interpretation is I'm expected to compute the following:

$$Answer = 2 \times l \times w + 2 \times w \times h + 2 \times h \times l + min(l, w, h)$$

# Design Space Exploration

```
Total: 1000 presents
Length: min=1
Length: max=30
Length: sum=46619
Length: avg=~15
```

# Implementation

## First Iteration

The input conforms to the following format: `\d\d?x\d\d?x\d\d?`

### Design Components

| Module                                          | Description                      | Complexity          | Thoughts       | Remarks  |
|-------------------------------------------------|----------------------------------|---------------------|----------------|----------|
| [`user_logic_tb`](user_logic_tb.sv)             | Testbench                        | :large_blue_circle: | :kissing_smiling_eyes: Copy-paste from previous puzzle | |
| [`user_logic`](user_logic.sv)                   | Logic top-level                  | :large_blue_circle: | :kissing_smiling_eyes: Simplified after moving logic | |
| [`tap_decoder`](tap_decoder.sv)                 | JTAG TAP deserializer            | :large_blue_circle: | :kissing_smiling_eyes: Copy-paste from previous puzzle | |
| FIXME                                           | FIXME                            | FIXME               | FIXME          | FIXME    |
| FIXME                                           | FIXME                            | FIXME               | FIXME          | FIXME    |
| FIXME                                           | FIXME                            | FIXME               | FIXME          | FIXME    |
| [`tap_encoder`](tap_encoder.sv)                 | JTAG TAP serializer              | :large_blue_circle: | :kissing_smiling_eyes: Copy-paste from previous puzzle | |

### Run Times

Full simulation: compilation and runtime (low-spec laptop):

| Run Times | Icarus Verilog | Verilator | Vivado Xsim | Vivado FPGA Build |
|-----------|----------------|-----------|-------------|-------------------|
| Real      | FIXME          | FIXME     | FIXME       | FIXME             |
| User      | FIXME          | FIXME     | FIXME       | FIXME             |
| Sys       | FIXME          | FIXME     | FIXME       | FIXME             |

### Resource Usage

| Ref Name | Used | Functional Category |
|----------|------|---------------------|
| FDRE     | FIXME |              FIXME |
| LUT2     | FIXME |              FIXME |
| LUT3     | FIXME |              FIXME |
| CARRY4   | FIXME |              FIXME |
| LUT6     | FIXME |              FIXME |
| LUT4     | FIXME |              FIXME |
| LUT5     | FIXME |              FIXME |
| LUT1     | FIXME |              FIXME |
| BUFG     | FIXME |              FIXME |
| BSCANE2  | FIXME |              FIXME |

## Second Iteration

FIXME

### Design Components

| Module                                          | Description                      | Complexity          | Thoughts       | Remarks  |
|-------------------------------------------------|----------------------------------|---------------------|----------------|----------|
| [`user_logic_tb`](user_logic_tb.sv)             | Testbench                        | :large_blue_circle: | :kissing_smiling_eyes: Copy-paste from previous puzzle | |
| [`user_logic`](user_logic.sv)                   | Logic top-level                  | :large_blue_circle: | :kissing_smiling_eyes: Simplified after moving logic | |
| [`tap_decoder`](tap_decoder.sv)                 | JTAG TAP deserializer            | :large_blue_circle: | :kissing_smiling_eyes: Copy-paste from previous puzzle | |
| FIXME                                           | FIXME                            | FIXME               | FIXME          | FIXME    |
| FIXME                                           | FIXME                            | FIXME               | FIXME          | FIXME    |
| FIXME                                           | FIXME                            | FIXME               | FIXME          | FIXME    |
| [`tap_encoder`](tap_encoder.sv)                 | JTAG TAP serializer              | :large_blue_circle: | :kissing_smiling_eyes: Copy-paste from previous puzzle | |

### Run Times

Full simulation: compilation and runtime (low-spec laptop):

| Run Times | Icarus Verilog | Verilator | Vivado Xsim | Vivado FPGA Build |
|-----------|----------------|-----------|-------------|-------------------|
| Real      | FIXME          | FIXME     | FIXME       | FIXME             |
| User      | FIXME          | FIXME     | FIXME       | FIXME             |
| Sys       | FIXME          | FIXME     | FIXME       | FIXME             |

### Resource Usage

| Ref Name | Used | Functional Category |
|----------|------|---------------------|
| FDRE     | FIXME |              FIXME |
| LUT2     | FIXME |              FIXME |
| LUT3     | FIXME |              FIXME |
| CARRY4   | FIXME |              FIXME |
| LUT6     | FIXME |              FIXME |
| LUT4     | FIXME |              FIXME |
| LUT5     | FIXME |              FIXME |
| LUT1     | FIXME |              FIXME |
| BUFG     | FIXME |              FIXME |
| BSCANE2  | FIXME |              FIXME |
