# Day 6: Trash Compactor

# Design Space Exploration

The puzzle description refers to multiple arithmetic operations.

```
123 328  51 64
 45 64  387 23
  6 98  215 314
*   +   *   +
```

The input data has these operations transposed in a list of values rather than a list of operations. Playing fair (no preprocessing outside of the FPGA) requires storing all the operands in the FPGA memory rather then doing computation on the fly which would have been possible if the array was rotated.

The order of magnitude of the number of operations has a strong impact on feasability of different methods, especially when it comes to storing the contents in memories. A quick count of `*` and `+` characters returns a total of 1000 operations. The length of operands also has an impact on memory sizing. A search for five digit numbers returns nothing, meaning that 14 bits (0 to 16383) is enough for encoding the numbers. This means that we can use a 14-bit wide memory to store the puzzle contents. Thus, we need three stores using 10-bit addresses on 14-bit values, which equates to two 36K BRAMs so no problem here.

Demuxing the contents looks trivial: two nested demux acting on digit to space transition and line endings. Final operation is a readback of all operands and running them using the appropriate arithmetic operator.

# Design Walkthrough

## External Interface

Still going with the tried and true JTAG / BSCANE2 for uploading the puzzle contents and reading back the solution. This allows reusing a large part of the prior implementation.

## Input Decoding

The input decoding is implemented in two steps:

- Deserialization of the JTAG bitstream in bytes by the `tap_decoder` module.
- Consolidation of ASCII digits into binary values and control of the signals for routing these values into the proper memory instance and address. This is done by the `input_decoder` module.

## Data Stores

As mentioned previously, we need three memory pools of 14-bit wide data words with 10-bit deep addresses. 

```verilog
arg_data_t mem_arg_data [0:2**ARG_ROW_WIDTH-1][0:2**ARG_COL_WIDTH-1];
```

Technically the fourth memory region is unwanted, but it is required to have a complete mapping for all `arg_col` values. The unused memory will be trimmed away during synthesis.

## Arithmetic Unit

The arithmetic unit takes all three operands read back from memory and computes the result named as `problem` in the puzzle description. I initially thought that the latency coming from the delay in the memory readback was to be compensated. However, it turns out that the column is updated on the character following the operand meaning that there is plenty of time built-in thus this latency is not a concern.

Latency is however a concern on the computation proper since the operand are non-trivially small, and a three-term multiplication followed by a 2:1 may not be the easiest structure for closing timing. I added a shift register delaying the valid strobe by several clock cycles simplifying any future adjustments would they be needed.

## Grand Total

The final stage of the computation is a simple addition of each new computation from the arithmetic unit. Since the implementation is simple I opted to directly do it in the `user_logic` module.

I chose a width of 64 bits which corresponds to upper power of two from the width of the values computed by the arithmetic unit.
