#!/usr/bin/env python
"""
Design Space Exploration for Advent of Code 15: Day 5 - Part 2
"""

import math
import os
import sys
from pathlib import Path
from typing import Iterator


def decode_inputs(file: Path) -> Iterator[str]:
    with open(file) as fh:
        for line in fh:
            yield line.strip().split()[0]


def user_logic(file: Path) -> int:
    strings = list(decode_inputs(file))
    i = len([str for str in strings if string_is_nice(str)[0]])
    print(f"Repeat pairs: {len([str for str in strings if string_is_nice(str)[1]])}")
    print(f"Repeat chars: {len([str for str in strings if string_is_nice(str)[2]])}")
    return i


def string_is_nice(string: str) -> list[bool]:
    pair = False
    for shift_amount in range(2, len(string) - 2):
        string_head = string[:-shift_amount]
        string_tail = string[shift_amount:]
        matching_chars = [h == t for h, t in zip(string_head, string_tail)]
        matching_chars_head = matching_chars[:-1]
        matching_chars_tail = matching_chars[1:]
        pair = any(h and t for h, t in zip(matching_chars_head, matching_chars_tail))
        if pair:
            break

    string_head = string[:-2]
    string_tail = string[2:]
    repeat = any(h == t for h, t in zip(string_head, string_tail))

    return [pair and repeat, pair, repeat]


# FPGA Friendly Implementation -------------------------------------------------


def fpga_tap_decoder(file: Path) -> Iterator[str]:
    with open(file) as fh:
        for line in fh:
            for c in line.strip().split()[0]:
                yield c
            yield "\n"
        yield "\0"


REPEAT_CHAR_DISTANCE = 2


def has_repeated_chars(string: str) -> bool:
    string_long_enough: bool = len(string) - REPEAT_CHAR_DISTANCE > 0
    if string_long_enough:
        is_last_char_repeated = string[-1] == string[-1 - REPEAT_CHAR_DISTANCE]
        return is_last_char_repeated
    return False


MIN_PAIR_DISTANCE = 2  # non-overlapping pair
CHAR_BITS = math.ceil(math.log2(26))
ASCII_LOWER_A = ord("a")


def has_repeated_pairs_ht(string: str) -> bool:
    # Hash table approach
    pair_table = [-1] * 2**CHAR_BITS * 2**CHAR_BITS  # cries in FPGA
    identical_pairs = False
    for i in range(len(string) - MIN_PAIR_DISTANCE + 1):
        pair = string[i : i + MIN_PAIR_DISTANCE]
        msb = ord(pair[0]) - ASCII_LOWER_A
        lsb = ord(pair[1]) - ASCII_LOWER_A
        index = (msb << CHAR_BITS) | lsb
        new_pair = pair_table[index] == -1
        if new_pair:
            pair_table[index] = i
        else:
            overlapping = i - pair_table[index] < MIN_PAIR_DISTANCE
            identical_pairs = identical_pairs or not overlapping
    for i in range(len(string) - MIN_PAIR_DISTANCE + 1):
        pair = string[i : i + MIN_PAIR_DISTANCE]
        msb = ord(pair[0]) - ASCII_LOWER_A
        lsb = ord(pair[1]) - ASCII_LOWER_A
        index = (msb << CHAR_BITS) | lsb
        pair_table[index] = -1
    for entry in pair_table:
        assert entry == -1, "Hash table not cleared"
    return identical_pairs


def has_repeated_pairs_dcc(string: str) -> bool:
    # Dual cross correlation approach
    start_offset = MIN_PAIR_DISTANCE
    stop_offset = len(string) - MIN_PAIR_DISTANCE
    identical_pairs = False
    for char_offset in range(start_offset, stop_offset):
        char_map = zip(string, string[char_offset:])
        identical_chars = [top == bot for top, bot in char_map]
        identical_pairs = identical_pairs or any(
            identical_chars[i] and identical_chars[i + 1]
            for i in range(len(identical_chars) - 1)
        )
    return identical_pairs


def fpga_user_logic(file: Path) -> int:
    result = 0
    string = ""
    repeated_chars = False
    for byte in fpga_tap_decoder(file):
        end_of_string = byte == "\n"
        if not end_of_string:
            string = string + byte
            repeated_chars = repeated_chars or has_repeated_chars(string)
        else:
            repeated_pairs_ht = has_repeated_pairs_ht(string)
            repeated_pairs_dcc = has_repeated_pairs_dcc(string)
            assert repeated_pairs_ht == repeated_pairs_dcc, (
                f"{string=}, HT: {repeated_pairs_ht}, DCC: {repeated_pairs_dcc}"
            )
            if repeated_pairs_ht and repeated_chars:
                result += 1
            string = ""
            repeated_chars = False
    return result


def main() -> int:
    os.chdir(Path(__file__).resolve().parent)
    file = "./input.txt" if len(sys.argv) < 2 else sys.argv[1]
    print(f"Contents {file=}")
    print(f"Result: {user_logic(file=Path(file))}")
    print(f"FPGA-style impl result: {fpga_user_logic(file=Path(file))}")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nInterrupted by user (Ctrl+C). Exiting...")
        sys.exit(1)
