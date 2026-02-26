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
        if wire in lut:
            return lut[wire]
        if wire.isdigit():
            return int(wire)
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


def rtl_decode_inputs(file: Path):
    scratch_str = ""
    scratch_int = 0
    first_operand_str = ""
    first_operand_int = 0
    second_operand_str = ""
    second_operand_int = 0
    is_rhs = False
    wire = ""
    opcode = ""
    with open(file) as fh:
        for i, line in enumerate(fh):
            for j, char in enumerate(line):
                if not is_rhs:
                    if char.islower():
                        scratch_str += char
                    elif char.isdigit():
                        scratch_int = (10 * scratch_int) + int(char)
                    elif char == " ":
                        if scratch_str:
                            if not first_operand_str:
                                first_operand_str = scratch_str
                                scratch_str = ""
                            elif not second_operand_str:
                                second_operand_str = scratch_str
                                scratch_str = ""
                            else:
                                raise ValueError(f"Error at row {i + 1}, col {j + 1}")
                            scratch_str = ""
                        elif scratch_int:
                            if not first_operand_int:
                                first_operand_int = scratch_int
                                scratch_int = 0
                            elif not second_operand_int:
                                second_operand_int = scratch_int
                                scratch_int = 0
                            else:
                                raise ValueError(f"Error at row {i + 1}, col {j + 1}")
                            scratch_int = 0
                    elif char.isupper() and not opcode:
                        if char == "N":
                            opcode = "NOT"
                        elif char == "A":
                            opcode = "AND"
                        elif char == "O":
                            opcode = "OR"
                        elif char == "L":
                            opcode = "LSHIFT"
                        elif char == "R":
                            opcode = "RSHIFT"
                    elif char == ">":
                        is_rhs = True
                else:
                    if char.islower():
                        wire += char
                    elif char == "\n":
                        if not opcode:
                            opcode = "LOAD"
                            if first_operand_str:
                                yield (wire, (0, 0), (1, first_operand_str), opcode)
                            else:
                                yield (wire, (0, 0), (0, first_operand_int), opcode)
                        else:
                            if opcode == "NOT":
                                yield (wire, (0, 0), (1, first_operand_str), opcode)
                            elif opcode in ("AND", "OR"):
                                if second_operand_str:
                                    yield (
                                        wire,
                                        (1, second_operand_str),
                                        (1, first_operand_str),
                                        opcode,
                                    )
                                else:
                                    yield (
                                        wire,
                                        (0, second_operand_int),
                                        (1, first_operand_str),
                                        opcode,
                                    )
                            else:
                                pass

                        scratch_str = ""
                        scratch_int = 0
                        first_operand_str = ""
                        first_operand_int = 0
                        second_operand_str = ""
                        second_operand_int = 0
                        is_rhs = False
                        wire = ""
                        opcode = ""


def main() -> int:
    os.chdir(Path(__file__).resolve().parent)
    file = "./input.txt" if len(sys.argv) < 2 else sys.argv[1]
    print(f"Using inputs from {file=}")
    explore_design_space = True
    if explore_design_space:
        explore(file=Path(file))
    print(f"Result: {user_logic(file=Path(file))}")
    instructions = list(rtl_decode_inputs(file=Path(file)))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nInterrupted by user (Ctrl+C). Exiting...")
        sys.exit(1)
