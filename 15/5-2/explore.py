#!/usr/bin/env python
"""
Design Space Exploration for Advent of Code 15: Day 5 - Part 2
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
    strings = list(decode_inputs(file))
    i = len([str for str in strings if string_is_nice(str)[0]])
    return i


def string_is_nice(string: str) -> list[bool]:
    pair = False
    for shift_amount in range(2, len(string) - 2):
        string_head = string[:-shift_amount]
        string_tail = string[shift_amount:]
        matching_chars = [h == t for h, t in zip(string_head, string_tail)]
        matching_chars_head = matching_chars[:-1]
        matching_chars_tail = matching_chars[1:]
        pair = any(h and t for h, t in zip(matching_chars_head, matching_chars_tail))
        if pair:
            break

    string_head = string[:-2]
    string_tail = string[2:]
    repeat = any(h == t for h, t in zip(string_head, string_tail))

    return [pair and repeat, pair, repeat]


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
