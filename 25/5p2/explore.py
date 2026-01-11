#!/usr/bin/env python
"""
Design Space Exploration for Advent of Code 25 Day 5 Cafeteria Part 2
"""

import math
import os
import sys
from pathlib import Path
from typing import Generator


def clog2(x):
    return math.ceil(math.log2(x))


def decode_inputs(file: Path) -> Generator[tuple[int, int]]:
    """
    Decode contents of the given file

    :param file: file containing the input values
    :return: list
    """

    for line in open(file):
        if len(line) > 1:
            values = tuple(map(int, line.strip().split("-")))
            if len(values) == 2:
                yield values
            else:
                break
        else:
            break


def user_logic(file: Path) -> int:
    """
    Puzzle solving logic

    :param file: file containing the input values
    :return: value to submit
    """

    perform_dse: bool = True
    if perform_dse:
        print("Performing Design Space Exploration...")
        ranges = list(decode_inputs(file=file))
        min_value, max_value = min(min(r) for r in ranges), max(max(r) for r in ranges)
        print(f"Min value: {min_value}")
        print(f"Max value: {max_value}")
        print(f"- bits: {clog2(max_value)}")

    return 0


def main() -> int:
    """
    Main function

    :return: Shell exit code
    """
    os.chdir(Path(__file__).resolve().parent)
    f = "./input.txt" if len(sys.argv) < 2 else sys.argv[1]
    print(f"{f=}")
    print(user_logic(file=Path(f)))

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nInterrupted by user (Ctrl+C). Exiting...")
        sys.exit(1)
