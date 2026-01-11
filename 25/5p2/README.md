# Day 5: Cafeteria - Part 2

# Lessons Learnt

*To be completed*

# Implementation

The takeaway from reading the puzzle statement for the second part is the strong similarity between both parts of the puzzle.

## Line Decoder

Formerly `input_decoder`, I opted to rename it to `line_decoder` which better reflects its purpose. A key difference however is that the second part of the input contents is no longer relevant and thus must be discarded. I added an `end_of_line` flag which has proven to simplify quite a lot the end of processing detection logic.

## Core Algorithm

The keyword in the second part of this puzzle is that **all of the IDs** must be detected, which is a significant departure from the first part which consisted of running a large list of given numbers.

My custom puzzle input contains large numbers requiring a 49 bits representation. Bruteforcing the solution would thus not be practical. Circling back to my implementation of the first part, I figured that a similar approach could work.

Imagining a simple setting:

```
.....AAAA...
....aAAAAa..
....a....a..
.....1234...
```

The core concept is to use not range but the immediates values off-by-one. Cascading these values down the chain of `range_check` units we get the extremes ranges left plus the ones from the intermediate `range_check` units.

```
.....AAAA...
...BBBB..a..
..b....b.a..
..b....b.a..
       ^
       Bad range value
```

The obvious problem here is that we are left by the intermediate ranges extremes coming from `range_check` later down the chain. My intuition is to run the process in reverse and correlate the range values which appear in both runs:

```
...BBBB.....
..b..AAAA...
..b.a....a..
..b.a....a..
    ^
    Bad range value


..b....b.a..     first run A before B
..b.a....a..     second run B before A`
correlate both values:
..b......a..     no more bad range values!
```

While thinking of how to simply arranging the flow of the range values my first thought was to execute two runs:

```
A -> B -> C
C -> B -> A
```

However this approach is subject to resource constraints: there was not much margin for the design to fit in the Zynq 7020 and the simulation runtimes, especially Icarus Verilog, were getting long (about a minute :grin:). Thinking more about the problem my intuition is that this problem is not associative, but rather cumlative (if this makes sense). This lead me to believe that running the data two times should result in the same results as running it once forward and once backward.

```
A -> B -> C -> A -> B -> C
```

The stop condition is simple: a counter at the end of the chain counts the number of range values which passed through. Conversely, the start condition is simply the end-of-file flag.
