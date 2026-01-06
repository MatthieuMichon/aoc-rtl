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
