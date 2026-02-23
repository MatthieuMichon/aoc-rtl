#!/usr/bin/env python
"""
Design Space Exploration for Advent of Code 15: Day 7 - Part 1
"""

import os
import sys
from collections import Counter
from pathlib import Path
from typing import Iterator

import graphviz

OPERATORS = {
    "AND",
    "LSHIFT",
    "NOT",
    "OR",
    "RSHIFT",
}
START_WIRE = "a"


def decode_inputs(file: Path) -> Iterator[tuple[str, dict]]:
    with open(file) as fh:
        for i, line in enumerate(fh):
            (lhs, rhs) = line.strip().split(" -> ")
            lhs = lhs.split(" ")
            if len(lhs) == 1:
                lhs = {
                    "operator": "let",
                    "operands": [lhs[0]],
                }
            elif len(lhs) == 2:
                assert lhs[0] == "NOT"
                lhs = {
                    "operator": "invert",
                    "operands": [lhs[1]],
                }
            else:
                assert len(lhs) == 3
                assert lhs[1] in OPERATORS - {
                    "NOT",
                }
                lhs = {"operator": lhs[1].lower(), "operands": [lhs[0], lhs[2]]}
            yield (rhs, lhs)


def explore(file: Path) -> None:
    instructions = list(decode_inputs(file=file))
    print(f"Instruction count {len(instructions)}")
    operator = Counter(lhs["operator"] for _, lhs in instructions)
    print(f"Operators: {operator=}")
    wires = Counter(rhs for rhs, _ in instructions)
    wire_lengths = Counter(map(len, wires.keys()))
    print(f"Individual wires per length: {wire_lengths}")


def user_logic(file: Path) -> int:
    def get_signal(wire: str) -> int:
        print(f"### {wire=}")
        if wire.isdigit():
            return int(wire)
        if wire in lut:
            return lut[wire]
        instruction = instructions[wire]
        operator = instruction["operator"]
        if operator in ("let", "forward"):
            value = get_signal(instruction["operands"][0])
            lut[wire] = value
        elif operator == "invert":
            raw_value = get_signal(instruction["operands"][0])
            value = ~raw_value & 65535
            lut[wire] = value
        elif operator == "and":
            value1 = get_signal(instruction["operands"][0])
            value2 = get_signal(instruction["operands"][1])
            value = value1 & value2
            lut[wire] = value
        elif operator == "or":
            value1 = get_signal(instruction["operands"][0])
            value2 = get_signal(instruction["operands"][1])
            value = value1 | value2
            lut[wire] = value
        elif operator == "lshift":
            value = get_signal(instruction["operands"][0]) << get_signal(
                instruction["operands"][1]
            )
            lut[wire] = value
        elif operator == "rshift":
            value = get_signal(instruction["operands"][0]) >> get_signal(
                instruction["operands"][1]
            )
            lut[wire] = value
        else:
            assert False, f"Unknown operator: {operator}"
        print(f"{wire=}, {instruction=} -> {value=}")
        return value

    lut = {}
    instructions = dict(decode_inputs(file=file))
    retval = get_signal("a")
    return retval


def main() -> int:
    os.chdir(Path(__file__).resolve().parent)
    file = "./input.txt" if len(sys.argv) < 2 else sys.argv[1]
    print(f"Using inputs from {file=}")
    explore_design_space = True
    if explore_design_space:
        explore(file=Path(file))
    # print(f"Result: {user_logic(file=Path(file))}")
    # print(f"FPGA Result: {fpga_user_logic(file=Path(file))}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nInterrupted by user (Ctrl+C). Exiting...")
        sys.exit(1)
