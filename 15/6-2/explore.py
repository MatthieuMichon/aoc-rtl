#!/usr/bin/env python
"""
Design Space Exploration for Advent of Code 15: Day 6 - Part 2
"""

import math
import os
import re
import sys
from collections import Counter, defaultdict
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
            start_row = int(m.group("corner0").split(",")[0])
            start_col = int(m.group("corner0").split(",")[1])
            end_row = int(m.group("corner1").split(",")[0])
            end_col = int(m.group("corner1").split(",")[1])
            instruction = {**locals()}  # feeling lazy
            yield instruction


def user_logic(file: Path) -> int:
    lit_lights = {}
    instructions = list(decode_inputs(file))
    explore_design_space = True
    if explore_design_space:
        explore(instructions)
    for i, instr in enumerate(instructions):
        for x in range(instr["start_row"], instr["end_row"] + 1):
            for y in range(instr["start_col"], instr["end_col"] + 1):
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
        (instr["start_row"] <= instr["end_row"])
        and (instr["start_col"] <= instr["end_col"])
        for instr in instructions
    )
    print(f"Corners are sorted: {corners_are_sorted}")
    sum_ = sum(
        (instr["end_row"] - instr["start_row"] + 1)
        * (instr["end_col"] - instr["start_col"] + 1)
        for instr in instructions
    )
    print(f"Total lights affected: {sum_}")
    max_ = max(
        (instr["end_row"] - instr["start_row"] + 1)
        * (instr["end_col"] - instr["start_col"] + 1)
        for instr in instructions
    )
    print(f"Max area: {max_}")
    min_ = min(
        (instr["end_row"] - instr["start_row"] + 1)
        * (instr["end_col"] - instr["start_col"] + 1)
        for instr in instructions
    )
    print(f"Min area: {min_}")
    avg = sum(
        (instr["end_row"] - instr["start_row"] + 1)
        * (instr["end_col"] - instr["start_col"] + 1)
        for instr in instructions
    ) / len(instructions)
    print(f"Average area: {avg:.0f}")
    for action in actions:
        avg = (
            sum(
                (instr["end_row"] - instr["start_row"] + 1)
                * (instr["end_row"] - instr["start_col"] + 1)
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


MAX_LIGHT_INTENSITY: int = 49
BITS_PER_LIGHT: int = math.ceil(math.log2(MAX_LIGHT_INTENSITY + 1))
RAM_WIDTH: int = 36
LIGHTS_PER_RAM_INSTANCE: int = RAM_WIDTH // BITS_PER_LIGHT
RAM_INSTANCES: int = math.ceil(LIGHT_GRID_SIZE[0] / BITS_PER_LIGHT)


def fpga_user_logic(file: Path) -> int:
    light_intensities = defaultdict(lambda: [0, 0])
    instructions = list(decode_inputs(file))
    for i, instr in enumerate(instructions):
        for row in range(instr["start_row"], 1 + instr["end_row"]):
            for ram_i in range(RAM_INSTANCES):
                ram_i_lsb_index = ram_i * LIGHTS_PER_RAM_INSTANCE
                ram_i_msb_index = ram_i_lsb_index + LIGHTS_PER_RAM_INSTANCE - 1
                ram_select = (
                    min(1 + instr["end_col"], 1 + ram_i_msb_index)
                    - max(instr["start_col"], ram_i_lsb_index)
                ) > 0
                if not ram_select:
                    continue
                ram_ligths = [
                    light_intensities[row, i]
                    for i in range(ram_i_lsb_index, ram_i_msb_index + 1)
                ]
                for ram_i_light in range(LIGHTS_PER_RAM_INSTANCE):
                    ram_i_light_index = ram_i_lsb_index + ram_i_light
                    ram_i_light_select = (
                        ram_i_light_index >= instr["start_col"]
                        and ram_i_light_index <= instr["end_col"]
                    )
                    if not ram_i_light_select:
                        continue
                    old_value = ram_ligths[ram_i_light][0]
                    if "on" == instr["action"]:
                        new_value = old_value + 1
                        ram_ligths[ram_i_light] = [new_value, new_value]
                    elif "off" == instr["action"]:
                        new_value = max(old_value - 1, 0)
                        ram_ligths[ram_i_light] = [new_value, old_value]
                    elif "toggle" == instr["action"]:
                        new_value = old_value + 2
                        ram_ligths[ram_i_light] = [new_value, new_value]
                for i in range(ram_i_lsb_index, ram_i_msb_index + 1):
                    light_intensities[row, i] = ram_ligths[i - ram_i_lsb_index]
    return sum(v[0] for v in light_intensities.values())


def main() -> int:
    os.chdir(Path(__file__).resolve().parent)
    file = "./test.txt" if len(sys.argv) < 2 else sys.argv[1]
    print(f"Contents {file=}")
    print(f"Result: {user_logic(file=Path(file))}")
    print(f"FPGA Result: {fpga_user_logic(file=Path(file))}")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nInterrupted by user (Ctrl+C). Exiting...")
        sys.exit(1)
