# tools/

## gcode_crc.py — RRF line CRCs

Adds and verifies RepRapFirmware line numbers, optionally with a line CRC:

```
N16 M569 P0 S0                          ; default: line number only
N16 M569 P0 S0 *37667                   ; with --crc
```

```bash
python3 tools/gcode_crc.py add                            # number macros/ and sys/ in place
python3 tools/gcode_crc.py add -o build -x sys/dsf-config.g    # deploy tree
python3 tools/gcode_crc.py add --crc -o build -x sys/dsf-config.g   # + CRC, standalone only
python3 tools/gcode_crc.py verify -x sys/dsf-config.g     # exit 1 on any mismatch
python3 tools/gcode_crc.py strip                          # remove N fields and CRCs again
python3 tools/gcode_crc.py selftest                       # check the CRC against known vectors
```

**`--crc` is opt-in because DSF does not support it.** Line numbers are
understood by both parsers (RRF's `StringParser` and DSF's
`DuetAPI/Commands/Code/Parser.cs`, which sets `CodeFlags.HasExplicitLineNumber`),
the `*` field only by RRF. So the default output is safe for standalone *and*
SBC machines, and `--crc` is added for SD-card machines only.

What each mode buys:

* **Line numbers only** — no corruption detection *on the machine*, but
  `verify` detects lost, inserted or reordered lines, because every `N` must
  equal its physical line number. On an SBC that check can run on the Pi after
  deployment; for a standalone machine it runs in the pipeline.
* **`--crc`** — RRF additionally validates every line as it reads it. Note how
  it fails: see the meta G-code section below.

`add` and `strip` are exact inverses in both modes: stripping a processed tree
reproduces the source byte for byte, including comment alignment and missing
trailing newlines. Default roots are `macros` and `sys`; `-x GLOB` excludes
files (with `-o` they are still copied through verbatim, so the deployed tree
stays complete), `-n` is a dry run, `--strict` fails when a line cannot be
numbered. `verify` always checks the line numbers and checks a CRC wherever a
line carries one; `verify --crc` additionally demands a CRC on every line.

### What the firmware actually does

Verified against RepRapFirmware `src/GCodes/GCodeBuffer/StringParser.cpp`,
`GCodeBuffer.cpp` and RRFLibraries `src/General/CRC16.cpp` — the G-code
dictionary alone is not accurate enough:

* CRC-16/CCITT ("XMODEM"): polynomial `0x1021`, initial value 0, no reflection,
  no final XOR. Exactly 5 decimal digits, zero padded — 1 to 3 digits select
  the legacy XOR checksum instead.
* The CRC covers every byte from the leading `N` up to but not including the
  `*`, **including the separator space in front of it** (`parsingGCode` feeds
  the space through `StoreAndAddToChecksum`). The dictionary prints
  `N100 G0 X100 F6000 *51369`, but 51369 is the CRC of the text *without* that
  space; with the separator the correct value is 54566. `selftest` prints both.
* Indentation stays **in front of** the `N`. `commandIndent` is only counted in
  the `parseNotStarted` state, i.e. before the line number; whitespace after
  the line number (`parsingWhitespace`) is fed to the CRC but does not count as
  indentation. Since meta command blocks are indentation-based, moving the `N`
  in front of the indentation would flatten every `if`/`while` block.
* `*` starts a CRC field **only** if the line carries an `N` and the parser is
  not inside `{ }`. A CRC therefore cannot be added without a line number.
* Line numbers need **not** be contiguous and not every line needs one.
  `StringParser::Init()` resets the per-line state, `LineFinished()` does
  `if (hadLineNumber) lineNumber = receivedLineNumber; else ++lineNumber;`, and
  there is no sequence check anywhere in `src/`. A missing CRC is only an error
  when `checksumRequired`/`crcRequired` is set, which happens exclusively via
  `GCodeBuffer::Enable()` (M575 comms properties on a serial channel), never
  for the file channel. `M110` is `//TODO break;` in 3.6 — not implemented.
  This tool still numbers every line: an unnumbered line cannot carry a CRC,
  and it breaks the "N equals physical line" invariant that `verify` uses to
  detect lost or inserted lines.

### Meta G-code

The `N` field and the CRC are consumed by the character-level state machine and
never reach `gb.buffer`, so keyword detection, expression parsing and the
argument length limit see exactly the same text as before. Three consequences:

* A bare `*` outside quotes and outside `{ }` cannot coexist with a line
  number — this applies in the default mode too, not just with `--crc` — it would be read as the CRC field. The multiplications in this repo
  were therefore wrapped: `set var.x = iterations * 2` became
  `set var.x = {iterations * 2}`, array indices on the left-hand side became
  `set var.a[{iterations * 2}] = …`. `{expr}` is a bracketed expression in
  `ExpressionParser` (only a comma inside makes it an array literal), so the
  value and the operator precedence are unchanged.
* Single quotes do **not** help. The parser has `parsingQuotedString` for `"`
  but no single-quote state at all, so the `*` in `M586 C'*'`
  (`sys/dsf-config.g`) would still start a CRC field — followed by zero digits,
  which the firmware scores as a bad checksum and drops the line. That file is
  parsed by DSF anyway and is excluded.
* A dropped line is worse for meta code than for plain G-code. On the file
  channel a bad CRC makes RRF discard the line silently (`Init(); return false`
  in `LineFinished`) — no error, no pause. If the discarded line is an `if` or
  `while`, its indented body still runs: `CheckMetaCommand` opens a plain block
  whenever the indentation increases. Verify in the pipeline; do not rely on
  the machine noticing.

### Before using this in the deploy pipeline — two caveats

1. **Never ship `--crc` output to an SBC machine.** On a Duet 3 with an SBC
   (this machine: see `sys/dsf-config.g` and the `M400 ; SBC specific wait`
   lines) the G-code in `/sys` and `/macros` is parsed by DuetControlServer,
   not by RRF, and DSF has no checksum or CRC support at all — `*` is an
   ordinary character there. `M569 P0 S0 *37667` yields the parameter value
   `0 *37667`, and `set var.now = a + b/1000 *50674` silently evaluates as a
   multiplication. Line numbers alone (the default) are fine on both.
2. **Never number files that are edited on the machine.** Any later edit
   invalidates that line's CRC and the firmware then drops the line, and it
   shifts every following line number out of step. This
   affects `sys/meltingplot/global-override.g` (operator-edited, on the DWC
   protected list) and everything the machine writes itself
   (`filaments/*/config.g`, `nozzle*.g`, `last-filament-temp.g`). Exclude them
   with `-x`.
