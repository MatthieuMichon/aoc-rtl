#!/usr/bin/env python
"""
Design Space Exploration for Advent of Code 15: Day 6 - Part 1
"""

import os
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Iterator

from PIL import Image

INPUT_REGEX = (
    r"(turn )?(?P<action>\w+) "
    r"(?P<corner0>\d+,\d+) through (?P<corner1>\d+,\d+)"
)
LIGHT_GRID_SIZE = (1000, 1000)


def decode_inputs(file: Path) -> Iterator[dict[str, Any]]:
    with open(file) as fh:
        for i, line in enumerate(fh):
            m = re.match(INPUT_REGEX, line)
            assert m, f"Invalid input {line} at line {i}"
            action = m.group("action")
            x0 = int(m.group("corner0").split(",")[0])
            y0 = int(m.group("corner0").split(",")[1])
            x1 = int(m.group("corner1").split(",")[0])
            y1 = int(m.group("corner1").split(",")[1])
            instruction = {**locals()}  # feeling lazy
            yield instruction


def user_logic(file: Path) -> int:
    lit_lights = {}
    instructions = list(decode_inputs(file))
    explore_design_space = True
    if explore_design_space:
        explore(instructions)
    for i, instr in enumerate(instructions):
        for x in range(instr["x0"], instr["x1"] + 1):
            for y in range(instr["y0"], instr["y1"] + 1):
                if "on" == instr["action"]:
                    lit_lights[(x, y)] = (True, i)
                elif "off" == instr["action"]:
                    lit_lights[(x, y)] = (False, i)
                elif "toggle" == instr["action"]:
                    lit_lights[(x, y)] = (not lit_lights.get((x, y), [False])[0], i)
    dump_lit_lights(lit_lights)
    return sum(v[0] for v in lit_lights.values())


def explore(instructions: list) -> None:
    actions = Counter(i["action"] for i in instructions)
    print(f"Got {actions.total()} instructions")
    for action in actions:
        print(f" - {actions[action]} '{action}' instructions")
    corners_are_sorted = all(
        (instr["x0"] <= instr["x1"]) and (instr["y0"] <= instr["y1"])
        for instr in instructions
    )
    print(f"Corners are sorted: {corners_are_sorted}")
    sum_ = sum(
        (instr["x1"] - instr["x0"] + 1) * (instr["y1"] - instr["y0"] + 1)
        for instr in instructions
    )
    print(f"Total lights affected: {sum_}")
    max_ = max(
        (instr["x1"] - instr["x0"] + 1) * (instr["y1"] - instr["y0"] + 1)
        for instr in instructions
    )
    print(f"Max area: {max_}")
    min_ = min(
        (instr["x1"] - instr["x0"] + 1) * (instr["y1"] - instr["y0"] + 1)
        for instr in instructions
    )
    print(f"Min area: {min_}")
    avg = sum(
        (instr["x1"] - instr["x0"] + 1) * (instr["y1"] - instr["y0"] + 1)
        for instr in instructions
    ) / len(instructions)
    print(f"Average area: {avg:.0f}")
    for action in actions:
        avg = (
            sum(
                (instr["x1"] - instr["x0"] + 1) * (instr["y1"] - instr["y0"] + 1)
                for instr in instructions
                if instr["action"] == action
            )
            / actions[action]
        )
        print(f" - {action} average area: {avg:.0f}")


def dump_lit_lights(lit_lights: dict) -> None:
    pixels_img = Image.new("1", LIGHT_GRID_SIZE, 0)
    updates_img = Image.new("RGB", LIGHT_GRID_SIZE, 0x000000)
    pixels = pixels_img.load()
    updates = updates_img.load()
    for (x, y), (is_on, depth) in lit_lights.items():
        pixels[x, y] = 1 if is_on else 0
        updates[x, y] = (
            int(depth * 255 / 300) << 16 if is_on else int(depth * 255 / 300)
        )
    pixels_img.save("lit_lights.png")
    updates_img.save("light_updates.png")


# FPGA Friendly Implementation -------------------------------------------------


WORD_WIDTH = 32
COLS = LIGHT_GRID_SIZE[0] // WORD_WIDTH + 1


def fpga_user_logic(file: Path) -> int:
    lit_lights = [[0x00000000] * COLS] * LIGHT_GRID_SIZE[1]
    instructions = list(decode_inputs(file))
    for i, instr in enumerate(instructions):
        for row in range(instr["y0"], instr["y1"] + 1):
            start_col = instr["x0"] // WORD_WIDTH
            end_col = instr["x1"] // WORD_WIDTH
            for i, ram_word in enumerate(lit_lights[row]):
                if (i < start_col) or (i > end_col):
                    continue
                if i != COLS - 1:
                    lit_lights[row][i] = 0xFFFFFFFF
                else:
                    # only single MSB in the last column
                    lit_lights[row][i] = 0xFF000000
    lit_light_sum = 0
    for row in lit_lights:
        for cell in row:
            lit_light_sum += cell.bit_count()
    return lit_light_sum


def main() -> int:
    os.chdir(Path(__file__).resolve().parent)
    file = "./input.txt" if len(sys.argv) < 2 else sys.argv[1]
    print(f"Contents {file=}")
    print(f"Result: {user_logic(file=Path(file))}")
    # print(f"FPGA-style impl result: {fpga_user_logic(file=Path(file))}")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nInterrupted by user (Ctrl+C). Exiting...")
        sys.exit(1)
