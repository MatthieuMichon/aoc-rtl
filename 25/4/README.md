# Design Space Exploration

## Input Data

| Property   | Input   | Example |
| ---------- | ------- | ------- |
| Rows       | 138     | 10      |
| Cols       | 138     | 10      |
| Char Types | 3       | 3       |
| Size (kB)  | 19      | 0.1     |

The input data has a simple and systematic structure, reading and streaming its contents in the FPGA should be straightforward.

The max number of rolls of paper (ROP) per cell is 8.

## Constants

Max line length is 138 chars according to the `input.txt` file. Assuming a max length of 160 chars for the implementation seems like a reasonable assumption.

- `MAX_LINE_LENGTH` = 160

# Computation Algorithms

## Naive Approach

The most obvious approach would consist in storing the complete array in memory and once complete run a scan over each cell adding the number of neighbors being tagged has having a ROP. In addition to requiring a memory for storing a 138x138 bit array, scanning each cell requires close to eight memory read transactions per cell. Although these access could be executed in parallel for reducing the runtimeby distributing the work across multiple processing units. A better way must exist.

## Single Pass Solution

I was eager to try something with more panache (overkill) than approach laid above. Having a hard look at the description I can't help but be reminded of multiple overlapping delay lines, my train of thought being something like the following: 

Lets consider the top line and its contribution to the line below:

```
..@@.@@@@.
0122223321
```

This computation can be done on the fly by simply adding single and double cycle delays:

```
..@@.@@@@.
...@@.@@@@.
....@@.@@@@.
001222233310
.0122223331. # trim corners
```

The computation is relevant only if there a ROP to start with, so this information will need to be stored somewhere.

```
Stored data for row N
..@@.@@@@.
0122223321
```

Upper row must be stored as well, thus before starting processing a new row, the current row stored in rank `row N` must be moved in rank `row N-1`.

```
Stored data for row N-1
..........
0000000000
Stored data for row N
..@@.@@@@.
0122223321
```

The same with the row below

```
Stored data for row N-1
..........
0000000000
Stored data for row N
..@@.@@@@.
0122223321
Stored data for row N+1
@@@.@.@.@@
2322121222
```

Colapsing the rows and accounting for the ROP present in the central location yields the expected results.

```
Stored data for row N-1
0000000000
0122223321
2322121222

2444344543 # sum
1333233432 # sum-1
..@@.@@@@. # mask
..xx.xx@x. # result
```

The result matches with the expected values from the puzzle statement.

So to recap:

- A smarter (or more appropriately a different) solution is therefore possible other than scanning the neighbor cells.
- Only three lines must be stored: two lines with the ROP count and one for the mask information.

# Design Walkthrough

## External Interface & TAP Decoder/Encoder

Still using the BSCANE2 primitive with ASCII byte decoding.

## Input Decoding

Each ASCII byte is remapped as a single bit encoding the presence of a ROP in the corresponding array cell.

In addition, a `last` signal is provided indicating the last cell of a row.

## Adjacent ROP Count

The first main component of the algorithm is an unit `adjacent_count` which translates binary input (ROP present or not) into a count of adjacent ROPs.
