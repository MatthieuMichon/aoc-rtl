#!/usr/bin/env python
"""
Design Space Exploration for Advent of Code 25: Day 10
"""

import enum
import os
import sys
from collections import defaultdict, deque
from collections.abc import Iterable
from pathlib import Path

DEBUG = False


class Char(enum.IntEnum):
    A_CHAR = 0x61  # lowercase: 'a'
    Z_CHAR = 0x7A  # lowercase: 'z'
    COLON_CHAR = 0x3A  # ':'
    SPACE_CHAR = 0x20  # ' '
    LF_CHAR = 0x0A  # Line Feed (NL)


def append_base(node_string: str) -> tuple[str, str]:
    """
    Converts a lowercase ASCII string into an '0x'-prefixed hexadecimal
        string based on an offset from 'a' (0x61).

        Args:
            node_string: The input string (e.g., 'gij').

        Returns:
            A tuple containing:
            1. The original node string.
            2. The calculated hexadecimal string (e.g., '0x060809').
    """
    node_base = f"0x{''.join(f'{ord(c) - Char.A_CHAR.value:02x}' for c in node_string)}"
    return (node_string, node_base)


def decode_lines(file: Path) -> Iterable:
    """
    Decode contents of the given file

    :param file: file containing the input values
    :return: list
    """

    for line in open(file):
        fields = line.split(" ")
        lights = fields[0][1:-1]
        buttons = fields[1:-1]
        # print(f"lights: {lights}, buttons: {buttons}")
        yield lights, buttons


def user_logic(file: Path) -> int:
    """
    Process input file yielding the submission value

    :param file: file containing the input values
    :return: value to submit
    """

    light_list = [l for l, b in decode_lines(file=file)]
    buttons_list = [b for l, b in decode_lines(file=file)]
    print(f"Max length: {max(map(len, light_list))}")
    print(f"Min length: {min(map(len, light_list))}")
    print(f"Avg length: {sum(map(len, light_list)) / len(light_list)}")
    print(f"Total lights: {sum(map(len, light_list))}")
    print(f"Max buttons: {max(map(len, buttons_list))}")
    print(f"Min buttons: {min(map(len, buttons_list))}")
    print(f"Avg buttons: {sum(map(len, buttons_list)) / len(buttons_list)}")
    print(f"Total buttons: {sum(map(len, buttons_list))}")
    # for lights, buttons in decode_lines(file=file):
    #     pass
    return 0


def main() -> int:
    """
    Main function

    :return: Shell exit code
    """
    os.chdir(Path(__file__).resolve().parent)
    files = ["./input.txt"]
    for f in files:
        print(f"In file {f}:")
        user_logic(file=Path(f))

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nInterrupted by user (Ctrl+C). Exiting...")
        sys.exit(1)
