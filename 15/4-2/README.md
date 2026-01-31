# Day 4: The Ideal Stocking Stuffer - Part 2

This second part increases the number of leading zeros which the digest shall match. Since each hexadecimal carries 16 combinations, the required runtime should increase by the same amount assuming an uniform distribution.



# Design Space Exploration

Using the Python script from part one and tweaking it for a digest with six leading zeros, I get the following results:

| Secret Key | Answer  | Input             | Hash                               |
|------------|---------|-------------------|------------------------------------|
| `yzbqklnj` | 9962624 | `yzbqklnj9962624` | `0000004b347bf4b398b3f62ace7cd301` |

I sometimes happen to trust but will always verify.

```bash
echo -n "yzbqklnj9962624" | md5sum
0000004b347bf4b398b3f62ace7cd301  -
```

A simple rule of three yields an on-board processing time of $$9962624 / 282749 \times 11.2 sec$$, approx 6 minutes and a half.

I could run the same firmware with the modification for accounting the extra digit, but this would be far too easy and the FPGA is not even 70 % full, this must be corrected.

# Implementation

## First Iteration

I added a basic dispatcher:

```verilog
assign md5_block_ready = ((per_unit_block_ready & per_unit_sel) != '0);
assign handshake_occured = md5_block_ready && md5_block_valid;

always_ff @(posedge clk) begin : dispatch_to_units
    if (handshake_occured) begin
        per_unit_sel <= {per_unit_sel[MD5_TOP_UNITS-2:0], per_unit_sel[MD5_TOP_UNITS-1]};
    end
end
```

Since only a single output event is generated, the output fetch logic is trivial:

```verilog
// Works because only one engine will match the correct result

always_ff @(posedge clk) begin
    result_valid <= 1'b0;
    for (int j = 0; j < MD5_TOP_UNITS; j++) begin
        if (per_unit_result_valid[j]) begin
            result_valid <= 1'b1;
            result_data <= per_unit_result_data[j];
        end
    end
end
```

### Resource Usage

I tried cramming eight instances of the MD5 core, but this didn't fit in the Zynq-7020. Reducing to seven did fit but barely:

```
WARNING: [Place 30-34] Design utilization is very high. Please run report_utilization command to see design utilization.
```

I paid for these slices, I will want to use them.

|                  Site Type                 |  Used | Fixed | Prohibited | Available | Util% |
|--------------------------------------------|-------|-------|------------|-----------|-------|
| Slice                                      | 13212 |     0 |          0 |     13300 | 99.34 |
|   SLICEL                                   |  8899 |     0 |            |           |       |
|   SLICEM                                   |  4313 |     0 |            |           |       |
| LUT as Logic                               | 49666 |     0 |          0 |     53200 | 93.36 |
|   using O5 output only                     |    21 |       |            |           |       |
|   using O6 output only                     | 41835 |       |            |           |       |
|   using O5 and O6                          |  7810 |       |            |           |       |
| LUT as Memory                              |    91 |     0 |          0 |     17400 |  0.52 |
|   LUT as Distributed RAM                   |     0 |     0 |            |           |       |
|     using O5 output only                   |     0 |       |            |           |       |
|     using O6 output only                   |     0 |       |            |           |       |
|     using O5 and O6                        |     0 |       |            |           |       |
|   LUT as Shift Register                    |    91 |     0 |            |           |       |
|     using O5 output only                   |    84 |       |            |           |       |
|     using O6 output only                   |     7 |       |            |           |       |
|     using O5 and O6                        |     0 |       |            |           |       |
| Slice Registers                            | 32003 |     0 |          0 |    106400 | 30.08 |
|   Register driven from within the Slice    | 16925 |       |            |           |       |
|   Register driven from outside the Slice   | 15078 |       |            |           |       |
|     LUT in front of the register is unused |   714 |       |            |           |       |
|     LUT in front of the register is used   | 14364 |       |            |           |       |

Floorplan didn't disappoint:

![](floorplan-7-md5-units.png)

## Second Iteration: Logic Optimization

Reviewing the module hierarchy, I noticed the `suffix_extractor` module was instantiated in each MD5 engine. Since only one of all the engines will yield a result passing through the `hash_filter` module, I decided that I could factorize this module. Doing so I also found a nasty latent bug just hidden thanks to just the right sequence of events.

In all this optimization allowed me to spare some resource usage but sadly not enough to shoe-horn an extra MD5 engine instance. Meaning I'm still stuck with seven of these.

## Third Iteration: Internal Configuration Clock

Two device configuration related primitives provide an internal clock signal: STARTUPE2 and USR_ACCESSE2. Instead of being gated from the host like the JTAG `tck` clock, these two former clocks are free running and should be able to provide continuous clock cycle at about 65 MHz.

Of course dealing with more than one clock means caring about *clock domain crossing*. Thankfully the whole design exposes some boundaries at which the information remains quite stable, specially in this puzzle with such short input contents.
