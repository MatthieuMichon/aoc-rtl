# Day 4: The Ideal Stocking Stuffer - Part 1

This one is going to be interesting.

# Design Space Exploration

My first intent is to start rolling a grass roots implementation of MD5 in Python. Knowing in advance the value of the expected answer is an absolute must thus, so `hashlib.md5` to the rescue.

```py
while True:
    hash = hashlib.md5(f"{secret_key}{i}".encode()).hexdigest()
    if hash.startswith(5 * "0"):
        return i
    i += 1
```

| Secret Key | Answer  | Input            | Hash                               |
|------------|---------|------------------|------------------------------------|
| `abcdef`   | 609043  | `abcdef609043`   | `000001dbbfa3a5c83a2d506429c7b00e` |
| `pqrstuv`  | 1048970 | `pqrstuv1048970` | `000006136ef2ff3b291c85725f17325c` |
| `yzbqklnj` | 282749  | `yzbqklnj282749` | `000002c655df7738246e88f6c1c43eb7` |

The value of the answer corresponds to the number of MD5 hashes required to be computed. With about one million, this begs the questions to consider whether or not it is worth using `tck` as a clock source, for this would require issuing a considerable amount of JTAG commands in the result read-back loop.

The alternative would be to use an internal clock source in order to avoid any board-level dependancies. Whatever, the first thing is to implement by hand the MD5 hash in Python first.

# Implementation

## First Iteration

Before deep diving into the MD5 hash, I decided to start with the groundwork consisting of the following operations:

- Capture of the secret key from the input contents
- Generation of the message suffix

### Secret Key Registration

A small but important subtility is that keys do not necessarily have the same number of characters. This has strong implications on how the input message is constructed. Assuming a max length of 12 chars, we get the following values:

| Input      | Secret Key Result (hex)      |
|------------|------------------------------|
| `abcdef`   | `0x616263646566000000000000` |
| `pqrstuv`  | `0x707172737475760000000000` |
| `yzbqklnj` | `0x797a62716b6c6e6a00000000` |

This filling operation is handled by a dedicated module [`line_decoder`](line_decoder.sv) which contains the following assignments:

```verilog
secret_key_bits <= secret_key_bits + 8'h8;
secret_key_value[SECRET_KEY_WIDTH-32'(secret_key_bits)-1-:INBOUND_DATA_WIDTH] <= inbound_data;
```

In essence, each new byte received from the host is appended to the secret key in a position which is shifted to the right each time a new byte is received. This differs from conventional LSB first or MSB first shifting operations, which found quite interesting.

### Message Suffix Computation

Circling back to the puzzle statement:

>  The input to the MD5 hash is your puzzle input followed by a number in decimal. You must find the lowest positive number (no leading zeroes: 1, 2, 3, ...).

Converting decimals into hexadecimal is usual for many puzzles, however doing the other way around is a first. I remember something called the [double dabble algorithm](https://en.wikipedia.org/wiki/Double_dabble), which is a method for converting binary numbers to decimal.

Thankfully the Wikipedia article contains a Verilog implementation (credits to [Ameer Abdelhadi](https://github.com/AmeerAbdelhadi)) which I will use as a base and tailor it to my needs. During the implementation I noticed that the formula for computing the number of digits $$(W+(W−4)/3)$$ yields wrong results for my use case: with a 23-bit binary number (toping at 8388607), it yields 8 digits while the correct number is 7.

It turns out the proper formula is $$D = \lceil W \cdot \log_{10}(2) \rceil$$. While implementing the BCD to ASCII conversion I realized that a match simpler approach was possible, by simply adding one to each ASCII digit and handling the carry. I left the implementation `bin2ascii` in a [Github Gist](https://gist.github.com/MatthieuMichon/f9313a34195417821a18205f2a987780) case of a future need.

### Secret Key and Counter Concatenation

Next step is merging both values into a single string+length pair which will be forwarded into the MD5 hash function. From experience, the support of backpressure (in the form of a ready signal) is mandatory as this decouples this block with the downstream implementation of the MD5 hash computation.

The implementation of this logic is quite tedious since it involves dealing with a lot of bit masking and shifting and it took several back and forth until things did behave as I wanted.

### Discrepancy Simulation vs FPGA

I returned dummy contents in order to avoid having Vivado pruning all my logic. Looking into the return value, I noticed that on-board runs produced a different value.

| Iverilog | Verilator | Xsim | FPGA |
|----------|-----------|------|------|
| 41       | 41        | 41   | 40   |

At least all three simulators agree so at least there is that. Looking at the waveform, I noticed that the `outbound_data` value varies while `outbound_valid` asserted, meaning that depending on the exact clock cycle at which the result is readback via the JTAG TAP the observed value may vary.

![](unstable_outbound_data_waveform.png)

I changed the logic to capture the result only when `outbound_valid` is deasserted.

```diff
always_ff @(posedge tck) begin: capture_result
    if (reset) begin
        outbound_valid <= 1'b0;
        outbound_data <= '0;
    end else begin
        outbound_valid <= msg_valid;
+        if (!outbound_valid)
+            outbound_data <= RESULT_WIDTH'($countones(msg_length)) + RESULT_WIDTH'($countones(msg_data));
-        outbound_data <= RESULT_WIDTH'($countones(msg_length)) + RESULT_WIDTH'($countones(msg_data));
    end
end
```

This somewhat dirty trick worked and all methods provide the same results:

| Iverilog | Verilator | Xsim | FPGA |
|----------|-----------|------|------|
| 40       | 40        | 40   | 40   |

## Second Iteration in Python

I'm using the [MD5 algorithm from Rosetta Code](https://rosettacode.org/wiki/MD5#Python) as stepping stone to implement my proper version as an intermediate stage before implementing it in SystemVerilog.

### Content Padding

My first change is to move the padding logic into a separate function, since I will be doing the same on the FPGA implementation.

From Wikipedia's [description of the padding](https://en.wikipedia.org/wiki/MD5#Algorithm):

> The input message is broken up into chunks of 512-bit blocks (sixteen 32-bit words); the message is padded so that its length is divisible by 512.

512 bits translates to 64 bytes, which is much larger than the inputs computed in the previous section. For the sake of simplicity, I intend to drop support for multi-block messages.

Its implementation being (edited knowing that all messages are smaller than 448 bits):

> The padding works as follows: first, a single bit, `1`, is appended to the end of the message. This is followed by as many zeros as are required to bring the length of the message up to 64 bits fewer than 512 bits. The remaining bits are filled up with 64 bits representing the length of the original message.

```py
def pad_message(msg: bytes) -> bytearray:
    msg_len_bits = 8 * len(msg)
    msg_buf = bytearray(msg) # copy into a mutable buffer
    msg_buf.append(0x80)  # Single MSB bit
    while len(msg_buf) != 56:
        msg_buf.append(0x00)
    msg_buf += msg_len_bits.to_bytes(8, byteorder="little")
    print(msg_buf.hex())
    return msg_buf
```

For reference, `msg_buf` = 0x616263646566308000(0x00 repeated)3800000000000000, which decomposes in "abcdef0<0x80>(<0x00> repeated)<7 * 8>(<0x00> repeated)". For a `msg` longer then 15 bytes, say 17 bytes, the trailing length field would look like "<0x01><0x10>(<0x00> repeated)" due to little-endian shenanigans.

FPGA implementation complexity: 2/10, most of the difficulty lies upstream for computing the suffix.
