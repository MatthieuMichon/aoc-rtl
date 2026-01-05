import sys
from collections import deque
from multiprocessing import Pool
from pathlib import Path
from typing import NamedTuple

IndicatorLigths = tuple[bool, ...]
Button = tuple[int, ...]
Joltages = tuple[int, ...]


class Machine(NamedTuple):
    lights: IndicatorLigths
    buttons: list[Button]
    joltages: Joltages

    def simulate_joltage_configuration(self, presses: tuple[int, ...]) -> Joltages:
        jolatages = [0] * len(self.joltages)
        for i, press_amount in enumerate(presses):
            for counter in self.buttons[i]:
                jolatages[counter] += press_amount
        return tuple(jolatages)


def read_file(file_name: Path) -> list[Machine]:
    result: list[Machine] = []
    with open(file_name) as f:
        for line in f.read().splitlines():
            parts = line.split()
            lights = ()
            buttons = []
            joltage: Joltages = ()

            for part in parts:
                first_char = part[0]
                value = part[1:-1]
                if first_char == "[":
                    lights = tuple([c == "#" for c in value])
                elif first_char == "(":
                    button = tuple([int(x) for x in value.split(",")])
                    buttons.append(button)
                elif first_char == "{":
                    joltage = tuple([int(x) for x in value.split(",")])
                else:
                    print("Invalid machine")
                    exit(2)

            machine = Machine(lights, buttons, joltage)
            result.append(machine)
    return result


def press_button(lights: IndicatorLigths, button: Button) -> IndicatorLigths:
    result = list(lights)
    for wire in button:
        result[wire] = not result[wire]
    return tuple(result)


def find_initialization_procedure(machine: Machine) -> int:
    target_lights = machine[0]
    buttons = machine[1]

    light_size = len(machine[0])
    init_lights = tuple([False] * light_size)
    queue = deque([(init_lights, 0)])

    seen = set()
    while len(queue) > 0:
        lights, button_presses = queue.popleft()

        for button in buttons:
            new_lights = press_button(lights, button)

            if new_lights == target_lights:
                return button_presses + 1

            if new_lights in seen:
                continue
            seen.add(new_lights)

            queue.append((new_lights, button_presses + 1))

    return -1


def run_initialization_procedures(machines: list[Machine]) -> int:
    with Pool() as thread_pool:
        return sum(thread_pool.imap(find_initialization_procedure, machines))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Please provide the input file!", file=sys.stderr)
        exit(-1)

    machines = read_file(Path(sys.argv[1]))

    x = run_initialization_procedures(machines)
    print(f"Phase 1: {x}")
