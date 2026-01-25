#!/usr/bin/env python
"""
Design Space Exploration for Advent of Code 15: Day 4 - Part 1
"""

import hashlib
import os
import sys
from pathlib import Path


def decode_inputs(file: Path) -> str:
    """
    Decode contents of the given file

    :param file: file containing the input values
    :return: hash prefix (secret key)
    """

    for line in open(file):
        return line.strip()


def user_logic(file: Path) -> int:
    """
    Puzzle solving logic

    :param file: file containing the input values
    :return: value to submit
    """

    secret_key = decode_inputs(file)
    i = 0
    print(f"| {'Secret Key':10} | {'Answer':7} | {'Input':16} | {'Hash':34} |")
    print(f"|{'-' * 12}|{'-' * 9}|{'-' * 18}|{'-' * 36}|")
    while True:
        hash = hashlib.md5(f"{secret_key}{i}".encode()).hexdigest()
        if hash.startswith(5 * "0"):
            input_str = f"{secret_key}{i}"
            current_hash = hash
            print(
                f"| `{secret_key:8}` | {i:7} | `{input_str:14}` | `{current_hash:32}` |"
            )
            break
        i += 1
    return i


def user_logic_fpga(file: Path) -> int:
    """
    Puzzle solving logic

    :param file: file containing the input values
    :return: value to submit
    """

    secret_key = decode_inputs(file)
    i = 0
    print(f"| {'Secret Key':10} | {'Answer':7} | {'Input':16} | {'Hash':34} |")
    print(f"|{'-' * 12}|{'-' * 9}|{'-' * 18}|{'-' * 36}|")
    while True:
        hash = fpga_md5(f"{secret_key}{i}".encode())
        break
    return i


def fpga_md5(msg: bytes):
    """
    FPGA-based MD5 hash function

    :param data: data to hash
    :return: hash value
    """
    # Implement FPGA-based MD5 hash function here
    pad_message(msg)


def pad_message(msg: bytes) -> bytearray:
    msg_buf = bytearray(msg)  # copy our input into a mutable buffer
    msg_len_bits = 8 * len(msg)
    msg_buf.append(0x80)  # Single MSB bit
    while len(msg_buf) != 56:
        msg_buf.append(0x00)
    msg_buf += msg_len_bits.to_bytes(8, byteorder="little")
    # print(msg_buf.hex())
    return msg_buf


def main() -> int:
    """
    Main function

    :return: Shell exit code
    """
    os.chdir(Path(__file__).resolve().parent)
    f = "./input.txt" if len(sys.argv) < 2 else sys.argv[1]
    print(f"{f=}")
    print(f"Result: {user_logic_fpga(file=Path(f))}")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nInterrupted by user (Ctrl+C). Exiting...")
        sys.exit(1)
