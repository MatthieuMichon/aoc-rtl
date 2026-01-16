# Day 3: Perfectly Spherical Houses in a Vacuum - Part 1

# Design Space Exploration

So, let's talk about the *infinite two-dimensional grid*, at a first glance there are 8192 (triggered the power of two decimal detection part in my brain) moves. This total is a reasonable amount speaking in terms of FPGA memory.

Obviously the FPGA will get nowhere running an algorithm with a $$\mathcal{O}(n^2)$$ time complexity. Thus before thinking of coding, a look at the pattern followed by the successive moves would be useful first step.

```
Direction (0, 1): 2070 moves
Direction (1, 0): 2027 moves
Direction (-1, 0): 2092 moves
Direction (0, -1): 2003 moves
Final rest X: -65
Final rest Y: 67
Min X: -72
Min Y: -3
Max X: 27
Max Y: 73
```

# Implementation

All the moves can be boxed using coordinates between -128 and 127, resulting in a 32K address space. Since a single bit is sufficient for representing the visited status, all I need is a single 36K BRAM. Obviously this puzzle could have been a tad more complex if the amplitude of the walk was larger.

Counting the visited houses is just a question of incrementing a counter when an empty house is encountered.

# Implementation

## First Iteration

Simply counting the number of moves would be an interesting intermediate step, as the expected number of already known.

Due to the small number of combinations, I was thinking of using a one-hot encoding where each direction is represented by a single dedicated bit. This makes the `line_decoder` module trivial to implement.

I also wanted to implement an improved design for simulating the BSCANE2 module using timings closer matching the behavior of the physical FPGA implementation. Also I noticed that the serialization of the input contents on a per-byte basis results is quite inefficient and would like to batch bytes into words of four or eight bytes. These changes would impact the testbench as well as the TAP decoder modules and should be quite easy to implement.
