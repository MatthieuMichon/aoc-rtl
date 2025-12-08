# Day 5: Cafeteria

My first take on this puzzle was too pessimistic: I thought that the large size of the context required for implementing this challenge would be troublesome to implement on a FPGA.

Re-reading the problem statement, I saw the keyword *any*:

> The ranges can also overlap; an ingredient ID is fresh if it is in any range.   

A combinatory logic property is that *any* and *all* are closely related. Negating the end result of *all* is equivalent to negating all the inputs being fed in an *any* operator. This is a significant breakthrough, for it allows solving this puzzle with a string of range check units.

# Design Space Exploration

My custom `input.txt` file contains 182 ranges and 1000 ingredient IDs. The amplitude of the ID values is important, for it determines the number of bits required to represent them. In my case it is between 1 and 561778236614610, with the latter being very close to 2**49 so 49 bits of data width it is.

To recap, I have the following design variables:

- `INGREDIENT_ID_RANGE_WIDTH`: 49
- `RANGE_CHECK_INSTANCES`: 200
- `MAX_INGREDIENT_QTY`: 1000

# Design Walkthrough

## External Interface & TAP Decoder/Encoder

Still using the BSCANE2 primitive since I don't want to bother with having to setup an UART link which will perform worse.

## Input Decoding

I figured that the input values must be decoded into two groups: values forming ranges and the remaining list of ingredient IDs. The transition is detected by the `detect_blank_line` sequential logic procedure (SLP).

Meanwhile numbers are extracted by the `extract_number` SLP and directly outputed.

## Range Check Units

The `range_check` design unit implements a dual comparison which is **reversed**: ingredient IDs which are inside the range are dropped. The key insight is that at the end of the series of `range_check` units all ingredient IDs which made it through are outside of all ranges.

## Result Computation

At this point obtaining the result is simply a matter of reversing the output of the `range_check` stages by calculating the difference between the total ingredient IDs and the number of spoiled ingredients.
