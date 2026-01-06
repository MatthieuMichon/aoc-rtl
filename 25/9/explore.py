#!/usr/bin/env python
"""
Design Space Exploration for Advent of Code 25: Day 9
"""

import enum
import math
import os
import sys
from collections.abc import Iterable
from pathlib import Path


class Char(enum.IntEnum):
    COMA_CHAR = 0x2C  # ','


def decode_inputs(file: Path) -> Iterable[tuple[int, int]]:
    """
    Decode contents of the given file

    :param file: file containing the input values
    :return: list
    """

    for line in open(file):
        (lhs, rhs) = line.split(chr(Char.COMA_CHAR.value))
        yield (int(lhs), int(rhs))


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
        tiles = list(decode_inputs(file=file))
        print(f"Total: {len(tiles)} tiles")
        (rows, cols) = zip(*tiles)
        print(f"Rows: min={min(rows)}, max={max(rows)}")
        print(f"Cols: min={min(cols)}, max={max(cols)}")
        max_potential_area = (max(rows) - min(rows)) * (max(cols) - min(cols))
        bits = clog2(max_potential_area)
        print(f"Max possible area: {max_potential_area} ({bits=})")
        print_tile_positions(tiles)
    max_area = 1
    for i, first_tile in enumerate(tiles):
        for j, second_tile in enumerate(tiles):
            row_diff = 1 + abs(rows[j] - rows[i])
            col_diff = 1 + abs(cols[j] - cols[i])
            area = row_diff * col_diff
            max_area = max(max_area, area)
    return max_area


def print_tile_positions(
    points: list[tuple[int, int]], width: int = 40, height: int = 20
):
    (rows, cols) = zip(*points)
    (min_rows, max_rows) = min(rows), max(rows)
    row_range = max_rows - min_rows
    (min_cols, max_cols) = min(cols), max(cols)
    col_range = max_cols - min_cols
    grid = [["." for _ in range(width)] for _ in range(height)]
    for row, col in points:
        norm_row = (row - min_rows) / row_range
        norm_col = (col - min_cols) / col_range
        grid_x = int(norm_row * (width - 1))
        grid_y = int(norm_col * (height - 1))
        grid[grid_y][grid_x] = "o"
    for row in grid:
        print("".join(row))


def main() -> int:
    """
    Main function

    :return: Shell exit code
    """
    os.chdir(Path(__file__).resolve().parent)
    f = "./input.txt" if len(sys.argv) < 2 else sys.argv[1]
    print(f"{f=}")
    print(f"Largest area: {user_logic(file=Path(f))}")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nInterrupted by user (Ctrl+C). Exiting...")
        sys.exit(1)
