#!/usr/bin/env python
"""
Design Space Exploration for Advent of Code 15: Day 6 - Part 2
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
                old_value = lit_lights.get((x, y), [0, 0])[0]
                if "on" == instr["action"]:
                    new_value = old_value + 1
                    lit_lights[(x, y)] = [new_value, new_value]
                elif "off" == instr["action"]:
                    new_value = max(old_value - 1, 0)
                    lit_lights[(x, y)] = [new_value, old_value]
                elif "toggle" == instr["action"]:
                    new_value = old_value + 2
                    lit_lights[(x, y)] = [new_value, new_value]
    dump_lit_lights(lit_lights, len(instructions))
    print(f"Max instantaneous: {max(v[1] for v in lit_lights.values())}")
    print(f"Max final: {max(v[0] for v in lit_lights.values())}")
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


def dump_lit_lights(lit_lights: dict, instruction_length: int) -> None:
    pixels_img = Image.new("RGB", LIGHT_GRID_SIZE, 0)
    max_pixels_img = Image.new("RGB", LIGHT_GRID_SIZE, 0)
    pixels = pixels_img.load()
    max_pixels = max_pixels_img.load()
    for (x, y), (intensity, max_intensity) in lit_lights.items():
        pixels[x, y] = (
            ((intensity & 0x30) << 18)
            + ((intensity & 0xC) << 12)
            + ((intensity & 0x3) << 6)
        )
        max_pixels[x, y] = (
            ((max_intensity & 0x30) << 18)
            + ((max_intensity & 0xC) << 12)
            + ((max_intensity & 0x3) << 6)
        )
    pixels_img.save("lights_intensity.png")
    max_pixels_img.save("max_lights_intensity.png")


# FPGA Friendly Implementation -------------------------------------------------


# To be done


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
