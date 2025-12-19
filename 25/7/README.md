# Day 7: Laboratories

# Design Space Exploration

## Puzzle Description

> How many times will the beam be split?

The puzzle question is suspiciously short. However the example contains a twist.

```
.......S.......
.......|.......
......|^|......
......|.|......
.....|^|^|.....
.....|.|.|.....
....|^|^|^|....
....|.|.|.|....
...|^|^|||^|...
...|.|.|||.|...
..|^|^|||^|^|..
..|.|.|||.|.|..
.|^|||^||.||^|.
.|.|||.||.||.|.
|^|^|^|^|^|||^| <--.
|.|.|.|.|.|||.|    |
                   |
         ^---------+-- Non-effective splitter
```

A simple algorithm would consist in memorizing the prior line and counting columns containing both a beam and splitter.

## Input Data

The input data is a rectangular array of fixed number of rows and columns.

| Contents | Rows | Columns |
|----------|------|---------|
| Example  | 16   | 15      |
| Input    | 142  | 142     |

Ignoring the `S` character, only a few others are used:

| Character | Description |
|-----------|-------------|
| `^`       | Beam        |
| `|`       | Splitter    |
| `.`       | Empty       |

## Design Properties

- MAX_COLS: 142
- MAX_ROWS: 142
- MAX_SPLITTERS: (MAX_ROWS/2)*MAX_COLS ~= 10000

# Computation Algorithm

A simple approach would consist in memorizing the prior line and superimposing the splitters in the current line for determining the positions of the beams.

However lets not forget we are targeting FPGAs and we can think laterally or better yet in four dimensions: two for the array of LUT/FF, one for the puzzle logic and finally the time during which the wave of information propagates through the circuit.

# Implementation

## General Diagram
