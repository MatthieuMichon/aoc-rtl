# Day 4: The Ideal Stocking Stuffer - Part 2

This second part increases the number of leading zeros which the digest shall match. Since each hexadecimal carries 16 combinations, the required runtime should increase by the same amount assuming an uniform distribution.

# Design Space Exploration

Using the Python script from part one and tweaking it for a digest with six leading zeros, I get the following results:

| Secret Key | Answer  | Input             | Hash                               |
|------------|---------|-------------------|------------------------------------|
| `yzbqklnj` | 9962624 | `yzbqklnj9962624` | `0000004b347bf4b398b3f62ace7cd301` |

I sometimes happen to trust but will always verify.

```bash
echo -n "yzbqklnj9962624" | md5sum
0000004b347bf4b398b3f62ace7cd301  -
```

A simple rule of three yields an on-board processing time of $$9962624 / 282749 \times 11.2 sec$$, approx 6 minutes and a half.

I could run the same firmware with the modification for accounting the extra digit, but this would be far too easy and the FPGA is not even 70 % full, this must be corrected.

# Implementation

## First Iteration
