
# Day 5: Doesn't He Have Intern-Elves For This? - Part 2

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

- TBD.

# Design Space Exploration

My first thought was to run a cross-correlation on the strings using an increasing byte shift amount for this first requirement pertaining to the pair of letters. The shift amount starts at two bytes since the pairs must not overlapping and stops when there is only one pair of bytes left to correlate.

```py
for shift_amount in range(2, len(string) - 2):
    string_head = string[:-shift_amount]
    string_tail = string[shift_amount:]
    matching_chars = [h == t for h, t in zip(string_head, string_tail)]
```

The matching characters can obviously be other things than a pair, thus a second cross-correlation with a single byte shift is used for detecting the presence of repeating matching chars which identifies the presence of a pair of letters. Thus the full implementation for the first requirement is as follows:

```py
for shift_amount in range(2, len(string) - 2):
    string_head = string[:-shift_amount]
    string_tail = string[shift_amount:]
    matching_chars = [h == t for h, t in zip(string_head, string_tail)]
    match_head = matching_chars[:-1]
    match_tail = matching_chars[1:]
    pair = any(h and t for h, t in zip(match_head, match_tail))
```

The second requirement consists in finding any character with an offset of two bytes. This is far simpler to implement:

```py
    string_head = string[:-2]
    string_tail = string[2:]
    repeat = any(h == t for h, t in zip(string_head, string_tail))
```

For reference, using my custom input contents I obtain the following results:

| pair and repeat | pair | repeat |
|-----------------|------|--------|
| 69              | 129  | 431    |
