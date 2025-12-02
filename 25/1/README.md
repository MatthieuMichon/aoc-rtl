The problem statement mentions a rotary dial with a number of steps fixed to 100. The input sequence corresponds to a number of steps being shifted from either side.

# Preliminary Study

Since I intend to use an FPGA for solving this problem, a practical way for looking at an implementation is to fold the design space.

With the dial going from 0 to 99, there is some modulo-100 lurking below the surface. This introduces a sort of roll-over similar to unsigned byte but limited to a small range than 0 to 255. Furthermore by using aliasing, shifts can be converted to be from always the same side, for example shift L95 is identical to R5.

Right of the bat there are a number of ways the final position could be computed. As I intend to use a hardware description language

The problem statement provides the following example sequence:

```
L68
L30
R48
L5
R60
L55
L1
L99
R14
L82
```

The [custom sequence](input.txt) I got is several order of magnitude larger with 4060 rows instead of ten. A quick check reveals a comparable number of left and right turns.

# Implementation

Keeping honest with the objective of having a neat solution I decided to go ahead using the BSCAN interface implementing a custom JTAG TAP endpoint. Text contents will be pushed as ASCII characters with rotations being separated with `0x0A` newlines. The return value being directly the value readback from the TAP.

This design as the merit of not relying on any external IOs including clocks, meaning it should be highly portable across all devices supported in one's installation of Vivado.
