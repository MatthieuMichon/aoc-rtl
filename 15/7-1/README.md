# Day 7: Some Assembly Required - Part 1

# Design Space Exploration

A quick check of the [input contents file](input.txt) shows 339 instructions and wires with name two characters long. The encoding of each instruction is non trivial with 5-bit for the operator, and operands being encoded as either two lowercase letters or a number requiring 16-bit. This results in a worst case of 39 bits corresponding to two RAMB36 blocks.

## Python Reference Design

After giving some thoughts, the decoding turned out to be simpler than expected. This is the case with Python, the FPGA implementation will likely be quite challenging.

Assuming the following operations:

```py
OPERATORS = {
    "AND",
    "LSHIFT",
    "NOT",
    "OR",
    "RSHIFT",
}
```

And the related decoding logic:

```py
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
```

The core logic is a simple recursion loop:

```py
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
```

Result using my custom input contents: **16076**

### FPGA-friendly Python Implementation

Doing some basic checks yields some insights:

```
Instruction count 339
Operators: operator=Counter({'and': 112, 'or': 80, 'rshift': 64, 'invert': 48, 'lshift': 32, 'let': 3})
Individual wires per length: Counter({2: 313, 1: 26})
```

I have 26 wires named with a single letter which I did not catch during the quick inspection. Thankfully this not change memory storage requirements nor the tracking table since 10-bit words largely covers a 27x26 arrangement. Thus will use the following entry structure:

- Opcode: 4-bit
  - 0b000: NOOP
  - 0b001: LD
  - 0b010: SET
  - 0b101: NOT
  - 0b100: AND
  - 0b101: OR
  - 0b110: LSHIFT
  - 0b111: RSHIFT

[//]: # (
{reg: [
    {bits: 3,  name: 'NOOP', attr: 0},
    {bits: 16},
    {bits: 1},
    {bits: 16},
    {bits: 1},
], config: {hspace: 1400}}
)

![](noop-wavedrom.svg)

[//]: # (
{reg: [
    {bits: 3,  name: 'LD', attr: 1},
    {bits: 16, name: 'IMMEDIATE', attr: 'uint16'},
    {bits: 18},
], config: {hspace: 1400}}
)

![](ld-wavedrom.svg)
