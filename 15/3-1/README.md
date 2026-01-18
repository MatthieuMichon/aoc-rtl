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

### Improved JTAG Data Serialization

A sore point of my previous implementations was the relatively slow data transfer rate. This was primarily due to serializing data on a per byte basis. Improving this situation would require batching data bits into words larger or much larger words.

My initial thoughts on this matter were to use 16 byte blocks for serialization and pad the remaining bytes with null bytes. For a typical 12 kbyte input length, this implementation would cut down by 16 the number of individual TCL commands. A thing I nearly forgot was that JTAG uses a LSB-first encoding, thus the bytes in each block should be reversed prior to serialization (this process could not be implemented in the FPGA since this would require knowing in advance the number of bytes to be padded in the last block).

#### Vivado TCL Script Changes

These changes mean breaking quite a lot of things in the TCL script, as it was operating on a per-line then per-byte basis. I changed the text file loading procedure to use blocks of N bytes instead of lines of text.

Using chunks of data instead of lines of text requires changing the translation type from the default (text) to binary.

```diff
-   set fhandle [open $file]
+   set fhandle [open $file rb]
```

Instead of looping over each line, the whole file is read in a single operation.

```diff
-while {[gets $fhandle line]>=0} {
-    lappend lines $line
-}
+set data [read $fhandle]
```

Padding length is calculated by subtracting the block size by the number of bytes sticking out after the last complete block. A modulo operation to the block size is applied to this value for handling cases where the file ends on a block boundary.

$$Padding(x)=(BlockSize-(x\%BlockSize))\%BlockSize$$

```tcl
set file_len [string length $data]
set delta_len [expr {$block_size - ($file_len % $block_size)}]
set padding_len [expr {$delta_len % $block_size}]
append data [string repeat \x00 $padding_len]
```

Iterating is done per chunk of the block size instead over each line, and following the required padding, finally the whole chunk is byte swap to comply with the JTAG protocol.

```tcl
if {$swap_bytes} {
    set hex [join [lreverse [regexp -all -inline .. $hex]] ""]
}
```

Furthermore, I was thinking of doing without having to go through the UPDATE state of the JTAG TAP controller. The documentation of the `scan_dr_hw_jtag` in the TCL command reference user-guide (ug835) calls out a method for doing so:

> To break up a long data register shift into multiple SDR shifts, specify an end_state of DRPAUSE. This will cause the first `scan_dr_hw_jtag` command to end in the DRPAUSE stable state, and then the subsequent scan_dr_hw_jtag commands will go to DREXIT2 state before going back to DRSHIFT.
