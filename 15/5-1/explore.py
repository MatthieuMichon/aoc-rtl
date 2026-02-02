#!/usr/bin/env python
"""
Design Space Exploration for Advent of Code 15: Day 5 - Part 1
"""

import os
import sys
from pathlib import Path
from typing import Iterator


def decode_inputs(file: Path) -> Iterator[str]:
    with open(file) as fh:
        for line in fh:
            yield line.strip().split()[0]


def user_logic(file: Path) -> int:
    explore_design_space = True
    if explore_design_space:
        strings = list(decode_inputs(file))
        print(f"Min string length: {min(len(s) for s in strings)} chars")
        print(f"Max string length: {max(len(s) for s in strings)} chars")

    strings = decode_inputs(file)
    i = len([str for str in strings if string_is_nice(str)])
    return i


def string_is_nice(string: str) -> bool:
    vowels = "aeiou"
    min_vowels = 3
    bad_strings = ["ab", "cd", "pq", "xy"]

    if sum(string.count(vowel) for vowel in vowels) < min_vowels:
        return False

    sliding_window = zip(string, string[1:])
    if not any(a == b for a, b in sliding_window):
        return False

    if any(bad_string in string for bad_string in bad_strings):
        return False

    return True


def main() -> int:
    os.chdir(Path(__file__).resolve().parent)
    file = "./input.txt" if len(sys.argv) < 2 else sys.argv[1]
    print(f"Contents {file=}")
    print(f"Result: {user_logic(file=Path(file))}")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nInterrupted by user (Ctrl+C). Exiting...")
        sys.exit(1)
