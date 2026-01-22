#!/usr/bin/env python
"""
Design Space Exploration for Advent of Code 15: Day 3 - Part 2
"""

import enum
import math
import os
import sys
from collections import Counter
from collections.abc import Iterable
from pathlib import Path


class Char(enum.IntEnum):
    LT_CHAR = 0x3C  # '<'
    GT_CHAR = 0x3E  # '>'
    CARET_CHAR = 0x5E  # '^'
    V_CHAR = 0x76  # lower-case 'v'


def decode_inputs(file: Path) -> Iterable[tuple]:
    """
    Decode contents of the given file

    :param file: file containing the input values
    :return: list
    """

    for line in open(file):
        for c in line:
            if c == chr(Char.LT_CHAR.value):
                yield (-1, 0)
            elif c == chr(Char.GT_CHAR.value):
                yield (1, 0)
            elif c == chr(Char.CARET_CHAR.value):
                yield (0, 1)
            elif c == chr(Char.V_CHAR.value):
                yield (0, -1)


def user_logic(file: Path) -> int:
    """
    Puzzle solving logic

    :param file: file containing the input values
    :return: value to submit
    """

    perform_dse: bool = True
    if perform_dse:
        print("Performing Design Space Exploration...")
        moves = list(decode_inputs(file=file))
        per_agent_moves = [moves[0::2], moves[1::2]]
        for agent_moves in per_agent_moves:
            c = Counter(agent_moves)
            print(f"Total: {len(agent_moves)} moves")
            for k, v in c.items():
                print(f"Direction {k}: {v} moves")
            x = 0
            y = 0
            min_x = 0
            min_y = 0
            max_x = 0
            max_y = 0
            for move in agent_moves:
                x += move[0]
                y += move[1]
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
            print(f"Final rest X: {x}")
            print(f"Final rest Y: {y}")
            print(f"Min X: {min_x}")
            print(f"Min Y: {min_y}")
            print(f"Max X: {max_x}")
            print(f"Max Y: {max_y}")
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
