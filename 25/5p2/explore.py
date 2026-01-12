#!/usr/bin/env python
"""
Design Space Exploration for Advent of Code 25 Day 5 Cafeteria Part 2
"""

import math
import os
import sys
from pathlib import Path
from typing import Any, Generator


def clog2(x):
    return math.ceil(math.log2(x))


def decode_inputs(file: Path) -> Generator[tuple[int, ...]]:
    """
    Decode contents of the given file

    :param file: file containing the input values
    :return: list
    """

    for line in open(file):
        if len(line) < 3:
            break
        else:
            values = tuple(map(int, line.strip().split("-")))
            yield values


def user_logic(file: Path) -> int:
    """
    Puzzle solving logic

    :param file: file containing the input values
    :return: value to submit
    """

    perform_dse: bool = True
    ranges = list(decode_inputs(file=file))
    if perform_dse:
        print("Performing Design Space Exploration...")
        min_value, max_value = min(min(r) for r in ranges), max(max(r) for r in ranges)
        print(f"Min value: {min_value}")
        print(f"Max value: {max_value}")
        print(f"- bits: {clog2(max_value)}")

    # Forward pass (prior assertion of the "virtual" end-of-file flag)

    stored_ranges = []
    for range in ranges:
        if not stored_ranges:
            stored_ranges.append(range)
            continue
        upstream_lower_id, upstream_upper_id = range
        for stored_range in stored_ranges:
            lower_id, upper_id = stored_range
            if (lower_id <= upstream_upper_id) and (upper_id >= upstream_lower_id):
                # Overlap
                lower_id = min(lower_id, upstream_lower_id)
                upper_id = max(upper_id, upstream_upper_id)
                stored_ranges.remove(stored_range)
                stored_ranges.append((lower_id, upper_id))
                break
        else:
            stored_ranges.append(range)
    if perform_dse:
        print(f"`range_check` modules with `range_set` high: {len(stored_ranges)}")

    # Final Pass Merge

    forwarded_ranges = []
    for lower_id, upper_id in stored_ranges:
        if not forwarded_ranges:
            forwarded_ranges.append([lower_id, upper_id])
            continue
        for upstream_lower_id, upstream_upper_id in forwarded_ranges:
            if (lower_id <= upstream_upper_id) and (upper_id >= upstream_lower_id):
                # Overlap
                lower_id = min(lower_id, upstream_lower_id)
                upper_id = max(upper_id, upstream_upper_id)
                forwarded_ranges.remove([upstream_lower_id, upstream_upper_id])
        else:
            forwarded_ranges.append([lower_id, upper_id])
    if perform_dse:
        print(f"`range_check` modules with `range_set` high: {len(forwarded_ranges)}")

    return sum([upper_id - lower_id + 1 for lower_id, upper_id in forwarded_ranges])


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
