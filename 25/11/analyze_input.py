#!/usr/bin/env python
"""
Design Space Exploration for Advent of Code 25: Day 11
"""

import enum
import os
import sys
from collections import defaultdict, deque
from collections.abc import Iterable
from pathlib import Path

DEBUG = False


class Char(enum.IntEnum):
    A_CHAR = 0x61  # lowercase: 'a'
    Z_CHAR = 0x7A  # lowercase: 'z'
    COLON_CHAR = 0x3A  # ':'
    SPACE_CHAR = 0x20  # ' '
    LF_CHAR = 0x0A  # Line Feed (NL)


def append_base(node_string: str) -> tuple[str, str]:
    """
    Converts a lowercase ASCII string into an '0x'-prefixed hexadecimal
        string based on an offset from 'a' (0x61).

        Args:
            node_string: The input string (e.g., 'gij').

        Returns:
            A tuple containing:
            1. The original node string.
            2. The calculated hexadecimal string (e.g., '0x060809').
    """
    node_base = f"0x{''.join(f'{ord(c) - Char.A_CHAR.value:02x}' for c in node_string)}"
    return (node_string, node_base)


def decode_inputs(file: Path) -> Iterable[tuple[tuple[str, str], tuple]]:
    """
    Decode contents of the given file

    :param file: file containing the input values
    :return: list
    """

    for line in open(file):
        (lhs, rhs) = line.split(chr(Char.COLON_CHAR.value))
        yield (
            append_base(lhs),
            tuple(
                append_base(node)
                for node in rhs.strip().split(chr(Char.SPACE_CHAR.value))
            ),
        )


class NodeIdMapper:
    """
    Models the SV logic for mapping sparse string IDs to contiguous integer IDs.
    """

    def __init__(self):
        self.lut = {}
        self.next_id = 0

    def get_contiguous_id(self, sparse_id: str) -> int:
        """
        Maps a 15-bit compact sparse ID to a contiguous integer ID.
        If the ID is new, it assigns a new contiguous ID.

        :param sparse_id: 15-bit compact node ID (e.g., "0x7f8e").
        :return: The corresponding contiguous integer ID (starting from 0).
        """
        if sparse_id in self.lut:
            contiguous_id = self.lut[sparse_id]
        else:
            contiguous_id = self.next_id
            self.lut[sparse_id] = contiguous_id
            self.next_id += 1
        return contiguous_id

    def get_num_nodes(self) -> int:
        """
        Returns the total number of unique nodes found so far.
        """
        return self.next_id


def user_logic(file: Path) -> int:
    """
    Process input file yielding the submission value

    :param file: file containing the input values
    :return: value to submit
    """

    outdegree = {}
    indegree = {}
    adj = defaultdict(list)
    node_id_map = NodeIdMapper()

    for lhs, rhs in decode_inputs(file=file):
        lhs = (node_id_map.get_contiguous_id(lhs[1]), *lhs)
        outdegree[lhs] = outdegree.get(lhs, 0) + len(rhs)
        indegree[lhs] = indegree.get(lhs, 0)
        for node in rhs:
            node = (node_id_map.get_contiguous_id(node[1]), *node)
            adj[lhs].append(node)
            indegree[node] = indegree.get(node, 0) + 1
            outdegree[node] = outdegree.get(node, 0)

    sorted_nodes = []
    max_queue_len = 0
    queue = deque()
    for node in indegree:
        if indegree[node] == 0:
            queue.append(node)
    while queue:
        max_queue_len = max(max_queue_len, len(queue))
        top = queue.popleft()
        sorted_nodes.append(top)
        for next_node in adj.get(top, []):
            indegree[next_node] -= 1
            if indegree[next_node] == 0:
                queue.append(next_node)
    start_node = next(node for node in sorted_nodes if node[1] == "you")
    end_node = next(node for node in sorted_nodes if node[1] == "out")
    trimed_sorted_nodes = []
    forward_node_list = False
    for i, node in enumerate(sorted_nodes):
        if node[1] == "you":
            forward_node_list = True
            trimed_sorted_nodes.append(
                (
                    node,
                    i,
                )
            )
        elif forward_node_list:
            trimed_sorted_nodes.append(
                (
                    node,
                    i,
                )
            )
            if node[1] == "out":
                forward_node_list = False
    for i, node in enumerate(trimed_sorted_nodes):
        print(f"Sorted Node #{i}: 0x{node[0]:03x}({node[0]: 4d})")
    return 0


def main() -> int:
    """
    Main function

    :return: Shell exit code
    """
    os.chdir(Path(__file__).resolve().parent)
    files = ["./input.txt"]
    for f in files:
        print(f"In file {f}:")
        user_logic(file=Path(f))

    return 0


if __name__ == "__main__":
    try:
        # No need to set up a signal handler!
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nInterrupted by user (Ctrl+C). Exiting...")
        sys.exit(1)
