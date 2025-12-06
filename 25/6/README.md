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

Still going with the tried and true JTAG / BSCANE2 for uploading the puzzle contents and reading back the solution. This allows reusing a large part of the prior implementation.
