#!/usr/bin/env python
"""
Design Space Exploration for Advent of Code 15: Day 2
"""

import enum
import math
import os
import sys
from collections.abc import Iterable
from pathlib import Path


class Char(enum.IntEnum):
    X_CHAR = 0x78  # lower-case 'x'


def decode_inputs(file: Path) -> Iterable[tuple]:
    """
    Decode contents of the given file

    :param file: file containing the input values
    :return: list
    """

    for line in open(file):
        res = map(int, line.split(chr(Char.X_CHAR.value)))
        yield tuple(res)


def user_logic(file: Path) -> int:
    """
    Puzzle solving logic

    :param file: file containing the input values
    :return: value to submit
    """

    def clog2(x):
        return math.ceil(math.log2(x))

    perform_dse: bool = True
    if perform_dse:
        print("Performing Design Space Exploration...")
        args = list(decode_inputs(file=file))
        print(f"Total: {len(args)} presents")
        ops_per_arg = list(zip(*args))
        print(f"Length: min={min(min(a) for a in ops_per_arg)}")
        print(f"Length: max={max(max(a) for a in ops_per_arg)}")
        print(f"Length: sum={sum(sum(a) for a in ops_per_arg)}")
        print(
            f"Length: avg=~{sum(sum(a) for a in ops_per_arg) // sum(len(a) for a in ops_per_arg)}"
        )
    return 0


def main() -> int:
    """
    Main function

    :return: Shell exit code
    """
    os.chdir(Path(__file__).resolve().parent)
    f = "./input.txt" if len(sys.argv) < 2 else sys.argv[1]
    print(f"{f=}")
    print(f"Result: {user_logic(file=Path(f))}")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nInterrupted by user (Ctrl+C). Exiting...")
        sys.exit(1)
