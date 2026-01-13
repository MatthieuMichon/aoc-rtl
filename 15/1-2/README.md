# 2015 Day 1: Not Quite Lisp - Part 2

Second parts of the puzzles are legit, the one at this specific puzzle is rather soft.

Status:

| Test                       | Status                |
|----------------------------|-----------------------|
| Simulation: Icarus Verilog | :white_check_mark: Ok |
| Simulation: Verilator      | :white_check_mark: Ok |
| Simulation: Vivado Xsim    | :white_check_mark: Ok |
| Synthesis: Vivado Zynq7    | :white_check_mark: Ok |
| On-board: Zynq7            | *Not tested*          |

# Lessons Learnt

- *Nothing yet*

# Puzzle Statement

> the position of the first character that causes him to enter the basement (floor -1).

The solution corresponds to the character count once the above condition is met.

# Design Space Exploration

Second part does not change the analysis.

### Implementation

Thankfully the changes are rather limited, consisting in some changes to the `floor_tracker` module.

### Design Components

| Module                                          | Description                      | Complexity          | Thoughts       | Remarks  |
|-------------------------------------------------|----------------------------------|---------------------|----------------|----------|
| [`user_logic_tb`](user_logic_tb.sv)             | Testbench                        | :large_blue_circle: | :kissing_smiling_eyes: Copy-paste from previous puzzle | |
| [`user_logic`](user_logic.sv)                   | Logic top-level                  | :large_blue_circle: | :kissing_smiling_eyes: Simplified after moving logic | |
| [`tap_decoder`](tap_decoder.sv)                 | JTAG TAP deserializer            | :large_blue_circle: | :kissing_smiling_eyes: Copy-paste from previous puzzle | |
| [`floor_tracker`](floor_tracker.sv)             | Puzzle solving logic             | :large_blue_circle: | :kissing_smiling_eyes: No suprises | No sign expansion, thus no `signed` keyword needed |
| [`tap_encoder`](tap_encoder.sv)                 | JTAG TAP serializer              | :large_blue_circle: | :kissing_smiling_eyes: Copy-paste from previous puzzle | |

### Run Times

Full simulation: compilation and runtime (low-spec laptop):

| Run Times | Icarus Verilog | Verilator | Vivado Xsim | Vivado FPGA Build |
|-----------|----------------|-----------|-------------|-------------------|
| Real      | 1.074s         | 8.237s    | 13.143s     | 2m1.195s          |
| User      | 1.017s         | 29.558s   | 11.222s     | 2m6.952s          |
| Sys       | 0.031s         | 2.913s    | 2.824s      | 0m7.731s          |

### Resource Usage

| Ref Name | Used | Functional Category |
|----------|------|---------------------|
| FDRE     |   93 |        Flop & Latch |
| LUT2     |   22 |                 LUT |
| LUT3     |   21 |                 LUT |
| CARRY4   |    8 |          CarryLogic |
| LUT6     |    6 |                 LUT |
| LUT4     |    4 |                 LUT |
| LUT5     |    2 |                 LUT |
| LUT1     |    2 |                 LUT |
| BUFG     |    1 |               Clock |
| BSCANE2  |    1 |              Others |
