# Day 1: Secret Entrance - Part 2

# Lessons Learnt

*To be completed*

# Design Space Exploration

I created a Python script ([`explore.py`](explore.py)) for getting a sense of the puzzle input contents and appropriately size the FPGA implementation.

```
Performing Design Space Exploration...
Total: 4059 rotations
Clicks: min=1, max=996
```

The largest number of clicks per rotation is 996, thus a 10-bit unsigned integer is warranted.

# Implementation

## Content Decoding

Compared to [part 1](/25/1/), the puzzle solving logic can no longer take the shortcut of mirroring the counter-clockwise rotation to the corresponding clockwise rotation. Thus, the line contents decoding logic requires some amount of reworking.

The easiest approach would consist in adding a dedicated single-bit signal indicating the direction of rotation.

### Resource Usage

```
Module line_decoder
Detailed RTL Component Info :
+---Adders :
	   3 Input   10 Bit       Adders := 1
	   2 Input   10 Bit       Adders := 1
+---Registers :
	               10 Bit    Registers := 1
	                8 Bit    Registers := 1
	                1 Bit    Registers := 3
+---Multipliers :
	               4x10  Multipliers := 1
+---Muxes :
	   2 Input   10 Bit        Muxes := 1
	   2 Input    1 Bit        Muxes := 4
```

## Dial Tracker

I used a hack in the first part where instead of rotating counter-clockwise the dial, I moved clockwise by an amount computed for resulting in the same position.

$$CW_{steps} = 100 - CCW_{steps}$$

The solution in the second part requires counting the number of times the hundred boundary is crossed, this shortcut no longer works. This means that the functions `x % 100` and `x / 100` be implemented.

Assuming $$Clicks = Quotient*100 + Remainder$$ we get:

$$Quotient = \lfloor Clicks / 100 \rfloor = \lfloor Clicks \times \frac{1}{100} \rfloor$$

Since the max rotation is limited to three digits and assuming the dial position at 99 for the worst case scenario, a fixed-point multiplier followed by a right shift will do the job just fine and would be much faster then performing an euclidean division.
