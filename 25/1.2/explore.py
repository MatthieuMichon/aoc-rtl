#!/usr/bin/env python
"""
Design Space Exploration for Advent of Code 25: Day 1
"""

import enum
import math
import os
import sys
from collections.abc import Iterable
from pathlib import Path


def decode_inputs(file: Path) -> Iterable[tuple[bool, int]]:
    """
    Decode contents of the given file

    :param file: file containing the input values
    :return: list
    """

    for line in open(file):
        yield (True if line[0] == "R" else False, int(line[1:]))


def user_logic(file: Path) -> int:
    """
    Puzzle solving logic

    :param file: file containing the input values
    :return: value to submit
    """

    perform_dse: bool = True
    if perform_dse:
        print("Performing Design Space Exploration...")
        rotations = list(decode_inputs(file=file))
        print(f"Total: {len(rotations)} rotations")
        (dir_, clicks) = zip(*rotations)
        print(f"Clicks: min={min(clicks)}, max={max(clicks)}")
    return 0


def main() -> int:
    """
    Main function

    :return: Shell exit code
    """
    os.chdir(Path(__file__).resolve().parent)
    f = "./input.txt" if len(sys.argv) < 2 else sys.argv[1]
    print(f"{f=}")
    user_logic(file=Path(f))

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nInterrupted by user (Ctrl+C). Exiting...")
        sys.exit(1)
