#!/usr/bin/env python
"""
Design Space Exploration for Advent of Code 15: Day 4 - Part 2
"""

import hashlib
import math
import os
import sys
from pathlib import Path


def decode_inputs(file: Path):
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
    i = 1
    print(f"| {'Secret Key':10} | {'Answer':7} | {'Input':16} | {'Hash':34} |")
    print(f"|{'-' * 12}|{'-' * 9}|{'-' * 18}|{'-' * 36}|")
    while True:
        hash = hashlib.md5(f"{secret_key}{i}".encode()).hexdigest()
        if hash.startswith(6 * "0"):
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
    i = 1
    # print(f"| {'Secret Key':10} | {'Answer':7} | {'Input':16} | {'Hash':34} |")
    # print(f"|{'-' * 12}|{'-' * 9}|{'-' * 18}|{'-' * 36}|")
    while True:
        txt = f"{secret_key}{i}"
        hash_int: int = fpga_md5(f"{secret_key}{i}".encode())
        hash_bytes = hash_int.to_bytes(16, byteorder="little")
        hash = f"{int.from_bytes(hash_bytes, byteorder='big'):032x}"
        print(f"{txt=}, {hash=}")
        break
        if hash.startswith(5 * "0"):
            input_str = f"{secret_key}{i}"
            current_hash = hash
            print(
                f"| `{secret_key:8}` | {i:7} | `{input_str:14}` | `{current_hash:32}` |"
            )
            break
        if i > 282749:
            print(f"Reached limit without finding a match")
            break
        i += 1
        # print("fpga: {:032x}".format(int.from_bytes(raw, byteorder="big")))
        # hash: str = hashlib.md5(f"{secret_key}{i}".encode()).hexdigest()
        # print(f"lib: {hash}")
        # break

    return i


rotate_amounts = [
    7,
    12,
    17,
    22,
    7,
    12,
    17,
    22,
    7,
    12,
    17,
    22,
    7,
    12,
    17,
    22,
    5,
    9,
    14,
    20,
    5,
    9,
    14,
    20,
    5,
    9,
    14,
    20,
    5,
    9,
    14,
    20,
    4,
    11,
    16,
    23,
    4,
    11,
    16,
    23,
    4,
    11,
    16,
    23,
    4,
    11,
    16,
    23,
    6,
    10,
    15,
    21,
    6,
    10,
    15,
    21,
    6,
    10,
    15,
    21,
    6,
    10,
    15,
    21,
]

functions = (
    16 * [lambda b, c, d: (b & c) | (~b & d)]
    + 16 * [lambda b, c, d: (d & b) | (~d & c)]
    + 16 * [lambda b, c, d: b ^ c ^ d]
    + 16 * [lambda b, c, d: c ^ (b | ~d)]
)

index_functions = (
    16 * [lambda i: i]
    + 16 * [lambda i: (5 * i + 1) % 16]
    + 16 * [lambda i: (3 * i + 5) % 16]
    + 16 * [lambda i: (7 * i) % 16]
)

constants = [int(abs(math.sin(i + 1)) * 2**32) & 0xFFFFFFFF for i in range(64)]
init_values = [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476]


def fpga_md5(msg: bytes) -> int:
    """
    FPGA-based MD5 hash function

    :param data: data to hash
    :return: hash value
    """

    ROUNDS = 64

    msg_buf: bytearray = pad_message(msg)
    # assert len(msg_buf) == 64
    hash_pieces = init_values[:]
    # chunk = msg_buf

    a, b, c, d = hash_pieces
    for i in range(ROUNDS):
        i_a, i_b, i_c, i_d = a, b, c, d
        f = functions[i](b, c, d) & 0xFFFFFFFF
        g = index_functions[i](i)
        msg_word = int.from_bytes(msg_buf[4 * g : 4 * g + 4], byteorder="little")
        to_rotate = a + f + constants[i] + msg_word
        # new_b = (b + left_rotate(to_rotate, rotate_amounts[i])) & 0xFFFFFFFF
        a, b, c, d = (
            d,
            (b + left_rotate(to_rotate, rotate_amounts[i])) & 0xFFFFFFFF,
            b,
            c,
        )
        # if i == 63:
        #     print(
        #         f"{msg=},{i=}: {i_a=:08x},{i_b=:08x},{i_c=:08x},{i_d=:08x},"
        #         f"T_CONST={constants[i]:08x},{f=:08x},{msg_word=:08x},{g=:08x} -> "
        #         f"{a=:08x},{b=:08x},{c=:08x},{d=:08x}"
        #     )
        #     sys.exit(1)

        # print(
        #     f"Round {i:02d} inputs: {f=:08x}, {constants[i]=:08x}, {int.from_bytes(chunk[4 * g : 4 * g + 4], byteorder="little")=:08x}"
        # )
        # print(f"Round {i:02d} outputs: {a=:08x}, {b=:08x}, {c=:08x}, {d=:08x}")

    for i, val in enumerate([a, b, c, d]):
        hash_pieces[i] += val
        hash_pieces[i] &= 0xFFFFFFFF
    return sum(x << (32 * i) for i, x in enumerate(hash_pieces))


def left_rotate(x, amount):
    x &= 0xFFFFFFFF
    return ((x << amount) | (x >> (32 - amount))) & 0xFFFFFFFF


def pad_message(msg: bytes) -> bytearray:
    msg_buf: bytearray = bytearray(msg)  # copy our input into a mutable buffer
    msg_len_bits: int = 8 * len(msg)
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
    print(f"Result: {user_logic(file=Path(f))}")
    # print(f"Result: {user_logic_fpga(file=Path(f))}")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nInterrupted by user (Ctrl+C). Exiting...")
        sys.exit(1)
