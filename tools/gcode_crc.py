#!/usr/bin/env python3
"""Add, verify or strip RepRapFirmware line CRCs in G-code files.

RRF 3.4+ accepts an optional 5-digit CRC-16 field at the end of a line:

    N100 G0 X100 F6000*51369

Semantics implemented here are taken from the firmware source
(RepRapFirmware src/GCodes/GCodeBuffer/StringParser.cpp, RRFLibraries
src/General/CRC16.cpp), not from the documentation alone:

* The CRC is a CRC-16/CCITT ("XMODEM"): polynomial 0x1021, initial value 0,
  no reflection, no final XOR.
* It covers every character from the leading 'N' up to (not including) the
  '*'.  Leading indentation is *not* covered: the firmware only starts
  accumulating once it has seen the line number (StringParser::AddToChecksum).
* A '*' only starts a CRC field if the line carries an 'N' line number and
  the parser is not inside { } braces.  Without an 'N' the '*' is stored as
  ordinary G-code -- therefore a CRC can only be added together with a line
  number.
* The CRC must be exactly 5 digits (zero padded); 1-3 digits select the old
  XOR checksum instead.
* Indentation must stay in front of the 'N': the firmware counts the indent
  of a line before parsing the line number, and whitespace *after* the line
  number does not count.  Meta command block structure depends on it.

Consequences that this tool enforces by skipping lines:

* Blank and comment-only lines get nothing.  The firmware skips CRC
  validation entirely for comment lines (LineFinished checks
  bufferState != parsingComment).
* A line that contains a bare '*' outside quotes and outside { } (e.g.
  `set var.x = iterations * 2`) cannot be protected: adding an 'N' would
  turn that multiplication into a CRC field.  Such lines are reported and
  left alone; use --strict to make that an error.

Read tools/README.md before using this in a deployment pipeline -- there are
deployment-level caveats (SBC/DSF mode, locally edited files) that this tool
cannot check for you.
"""

from __future__ import annotations

import argparse
import fnmatch
import os
import re
import sys
from pathlib import Path

# --------------------------------------------------------------------------
# CRC-16/CCITT, initial value 0 -- identical to RRFLibraries CRC16::Update()
# --------------------------------------------------------------------------

_CRC16_TABLE = []
for _i in range(256):
    _c = _i << 8
    for _ in range(8):
        _c = ((_c << 1) ^ 0x1021) & 0xFFFF if _c & 0x8000 else (_c << 1) & 0xFFFF
    _CRC16_TABLE.append(_c)


def crc16_ccitt(data: bytes) -> int:
    """CRC-16/XMODEM over raw bytes (UTF-8 as the firmware sees them)."""
    crc = 0
    for byte in data:
        crc = ((crc << 8) & 0xFFFF) ^ _CRC16_TABLE[((crc >> 8) ^ byte) & 0xFF]
    return crc


# --------------------------------------------------------------------------
# Line parsing -- mirrors the StringParser::Put() state machine
# --------------------------------------------------------------------------

_N_FIELD = re.compile(r"[Nn](\d+)[ \t]*")
_CRC_FIELD = re.compile(r"\*(\d+)[ \t]*")

SKIP_BLANK = "blank"
SKIP_COMMENT = "comment"
SKIP_STAR = "bare-asterisk"


def scan(rest: str, has_line_number: bool):
    """Walk a line body the way the firmware does.

    Returns (crc_index, comment_index, bare_star_indices) as offsets into
    'rest', which is the text after an existing N field (if any).
    """
    in_quote = False
    braces = 0
    bare_stars = []
    for i, c in enumerate(rest):
        if in_quote:
            if c == '"':
                in_quote = False
            continue
        if c == '"':
            in_quote = True
        elif c == "{":
            braces += 1
        elif c == "}":
            braces = max(0, braces - 1)
        elif c == ";":
            return None, i, bare_stars
        elif c == "*" and braces == 0:
            if has_line_number:
                return i, None, bare_stars
            bare_stars.append(i)
    return None, None, bare_stars


class Line:
    """One decomposed source line."""

    __slots__ = ("eol", "indent", "code", "gap", "comment",
                 "old_number", "old_crc", "skip")

    def __init__(self, raw: str):
        self.skip = None
        self.old_number = None
        self.old_crc = None
        self.comment = ""
        self.gap = ""

        text = raw.rstrip("\n")
        self.eol = raw[len(text):]
        text = text.rstrip("\r")
        self.eol = raw[len(text):]

        stripped = text.lstrip(" \t")
        self.indent = text[:len(text) - len(stripped)]
        self.code = ""

        if not stripped:
            self.skip = SKIP_BLANK
            self.code = stripped
            return
        if stripped.startswith(";"):
            self.skip = SKIP_COMMENT
            self.code = stripped
            return

        body = stripped
        m = _N_FIELD.match(body)
        if m:
            self.old_number = int(m.group(1))
            body = body[m.end():]

        crc_at, comment_at, bare = scan(body, m is not None)

        # 'tail' is everything the firmware discards: the whitespace and the
        # comment behind the code (and behind the CRC field, if present).
        if crc_at is not None:
            mc = _CRC_FIELD.match(body[crc_at:])
            if mc:
                self.old_crc = mc.group(1)
                tail = mc.group(0)[len(mc.group(1)) + 1:] + body[crc_at + mc.end():]
            else:
                # '*' present but not followed by digits: the firmware
                # discards the rest of the line, so treat it the same way.
                self.old_crc = ""
                tail = body[crc_at + 1:]
            code = body[:crc_at]
            # The separator space in front of '*' belongs to the CRC field, not
            # to the comment gap -- drop exactly the one space that we emit.
            sep = code[len(code.rstrip(" \t")):]
            if sep:
                tail = sep[:-1] + tail
                code = code[:len(code) - 1]
        elif comment_at is not None:
            code = body[:comment_at]
            tail = body[comment_at:]
        else:
            code = body
            tail = ""

        self.code = code.rstrip(" \t")
        # Whitespace between code and comment is preserved verbatim so that
        # add and strip are exact inverses of each other.
        self.gap = code[len(self.code):] + tail[:len(tail) - len(tail.lstrip(" \t"))]
        self.comment = tail.lstrip(" \t")

        if not self.code:
            # Line carried only a comment (possibly behind an N field).
            self.skip = SKIP_COMMENT
            self.code = stripped
            self.gap = ""
            self.comment = ""
            return
        if bare:
            self.skip = SKIP_STAR

    # -- rendering ---------------------------------------------------------

    def _join(self, head: str) -> str:
        return head + self.gap + self.comment + self.eol

    def stripped_text(self) -> str:
        return self._join(self.indent + self.code)

    def number_text(self, number: int) -> str:
        """Line number only -- no CRC field (DSF/SBC compatible)."""
        return self._join("%sN%d %s" % (self.indent, number, self.code))

    def crc_text(self, number: int) -> str:
        body = self.crc_body(number)
        return self._join("%s%s*%05d" % (self.indent, body, self.expected_crc(number)))

    def crc_body(self, number: int) -> str:
        """The text the firmware checksums: line number, code, separator."""
        return "N%d %s " % (number, self.code)

    def expected_crc(self, number: int) -> int:
        return crc16_ccitt(self.crc_body(number).encode("utf-8"))


# --------------------------------------------------------------------------
# File level operations
# --------------------------------------------------------------------------

class Stats:
    def __init__(self):
        self.files = 0
        self.changed = 0
        self.numbered = 0
        self.crcs = 0
        self.copied = 0
        self.skipped_star = 0
        self.errors = 0


def iter_files(roots, excludes):
    """Yield (path, excluded).  Excluded files are still reported so that they
    can be copied verbatim into an output tree."""
    for root in roots:
        p = Path(root)
        if p.is_file():
            candidates = [p]
        else:
            candidates = sorted(q for q in p.rglob("*") if q.is_file())
        for f in candidates:
            rel = f.as_posix()
            yield f, any(fnmatch.fnmatch(rel, pat) or fnmatch.fnmatch(f.name, pat)
                         for pat in excludes)


def read_lines(path: Path):
    return path.read_bytes().decode("utf-8").splitlines(keepends=True)


def readable(path: Path) -> bool:
    """True if the file is text we can safely rewrite."""
    data = path.read_bytes()
    if b"\x00" in data:
        return False
    try:
        data.decode("utf-8")
    except UnicodeDecodeError:
        return False
    return True


def transform(path: Path, lines, mode, with_crc, stats, report):
    out = []
    changed = False
    for number, raw in enumerate(lines, 1):
        line = Line(raw)
        if line.skip == SKIP_STAR:
            stats.skipped_star += 1
            report.append("%s:%d: bare '*' outside { } -- cannot take a line "
                          "number: %s" % (path, number, line.code.strip()))
            new = line.stripped_text() if line.old_number is not None else raw
        elif line.skip:
            new = raw
        elif mode == "add":
            new = line.crc_text(number) if with_crc else line.number_text(number)
            stats.numbered += 1
            stats.crcs += 1 if with_crc else 0
        else:  # strip
            new = line.stripped_text()
        if new != raw:
            changed = True
        out.append(new)
    if changed:
        stats.changed += 1
    return out, changed


def verify(path: Path, lines, require_crc, stats, report):
    """Check line numbers, and CRCs wherever a line carries one."""
    ok = True
    for number, raw in enumerate(lines, 1):
        line = Line(raw)
        if line.skip == SKIP_STAR:
            stats.skipped_star += 1
            continue
        if line.skip:
            continue
        if line.old_number is None:
            ok = False
            stats.errors += 1
            report.append("%s:%d: no line number" % (path, number))
            continue
        stats.numbered += 1
        if line.old_number != number:
            ok = False
            stats.errors += 1
            report.append("%s:%d: line number is N%s" % (path, number, line.old_number))
            continue
        if line.old_crc is None:
            if require_crc:
                ok = False
                stats.errors += 1
                report.append("%s:%d: no CRC" % (path, number))
            continue
        stats.crcs += 1
        if len(line.old_crc) != 5:
            ok = False
            stats.errors += 1
            report.append("%s:%d: CRC field is %d digits, must be 5"
                          % (path, number, len(line.old_crc)))
            continue
        want = line.expected_crc(number)
        if int(line.old_crc) != want:
            ok = False
            stats.errors += 1
            report.append("%s:%d: CRC mismatch -- file says %s, computed %05d"
                          % (path, number, line.old_crc, want))
    return ok


def selftest() -> int:
    checks = [
        (b"123456789", 0x31C3),                     # CRC-16/XMODEM check value
        (b"N100 G0 X100 F6000", 51369),             # example from the RRF docs
        (b"", 0),
    ]
    failed = 0
    for data, want in checks:
        got = crc16_ccitt(data)
        state = "ok " if got == want else "FAIL"
        if got != want:
            failed += 1
        print("%s crc16(%r) = %d (expected %d)" % (state, data, got, want))

    # The G-code dictionary prints "N100 G0 X100 F6000 *51369", but 51369 is
    # the CRC of the text *without* the separator space.  The firmware feeds
    # every character before the '*' into the CRC, the space included, so a
    # space-separated line carries a different value than the dictionary shows.
    spaced = Line("G0 X100 F6000\n").crc_text(100)
    print("with separator: %r (51369 is the value without the space)" % spaced)
    print("without --crc:  %r" % Line("G0 X100 F6000\n").number_text(100))

    src = 'if global.result != 0 ; comment\n'
    line = Line(src)
    built = line.crc_text(7)
    print("round trip: %r -> %r" % (src, built))
    if Line(built).code != line.code or Line(built).old_number != 7:
        print("FAIL round trip")
        failed += 1
    if not verify_string(built, 7):
        print("FAIL self verify")
        failed += 1
    return 1 if failed else 0


def verify_string(text: str, number: int) -> bool:
    line = Line(text)
    return (line.old_crc is not None and len(line.old_crc) == 5
            and int(line.old_crc) == line.expected_crc(number))


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        description="Add, verify or strip RRF line numbers and CRCs "
                    "(CRC-16/CCITT, init 0).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Default roots are 'macros' and 'sys' relative to the current "
               "directory.  Use -o to write the result into a deployment tree "
               "instead of rewriting the working tree.  --crc is opt-in "
               "because DSF (SBC mode) does not support checksum fields.")
    ap.add_argument("mode", choices=("add", "verify", "strip", "selftest"))
    ap.add_argument("paths", nargs="*", help="files or directories")
    ap.add_argument("-o", "--output-dir", metavar="DIR",
                    help="write results into DIR instead of in place")
    ap.add_argument("-n", "--dry-run", action="store_true",
                    help="report what would change, write nothing")
    ap.add_argument("-x", "--exclude", action="append", default=[], metavar="GLOB",
                    help="skip paths matching GLOB (repeatable)")
    ap.add_argument("-c", "--crc", action="store_true",
                    help="also append the CRC field -- standalone (SD card) "
                         "machines only, DSF/SBC does not support it; "
                         "with 'verify' it demands a CRC on every line")
    ap.add_argument("--strict", action="store_true",
                    help="fail if a line cannot be numbered")
    ap.add_argument("-q", "--quiet", action="store_true")
    args = ap.parse_args(argv)

    if args.mode == "selftest":
        return selftest()

    roots = args.paths or ["macros", "sys"]
    missing = [r for r in roots if not Path(r).exists()]
    if missing:
        print("error: no such path: %s" % ", ".join(missing), file=sys.stderr)
        return 2

    stats = Stats()
    report = []
    all_ok = True

    for path, excluded in iter_files(roots, args.exclude):
        if excluded or not readable(path):
            # Keep the deployed tree complete: copy anything we do not touch.
            if args.output_dir and not args.dry_run:
                dest = Path(args.output_dir) / path
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(path.read_bytes())
            stats.copied += 1
            continue
        lines = read_lines(path)
        stats.files += 1

        if args.mode == "verify":
            all_ok &= verify(path, lines, args.crc, stats, report)
            continue

        out, changed = transform(path, lines, args.mode, args.crc, stats, report)
        if args.dry_run:
            continue
        if args.output_dir:
            dest = Path(args.output_dir) / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text("".join(out), encoding="utf-8")
        elif changed:
            path.write_text("".join(out), encoding="utf-8")

    if report and not args.quiet:
        for entry in report:
            print(entry)

    if not args.quiet:
        if args.mode == "verify":
            print("%d files, %d lines numbered, %d with CRC, %d problems, "
                  "%d lines skipped"
                  % (stats.files, stats.numbered, stats.crcs, stats.errors,
                     stats.skipped_star))
        elif args.mode == "add":
            print("%d files, %d changed, %d lines numbered, %d with CRC, "
                  "%d lines skipped, %d files passed through"
                  % (stats.files, stats.changed, stats.numbered, stats.crcs,
                     stats.skipped_star, stats.copied))
        else:
            print("%d files, %d changed, %d lines skipped, %d files passed through"
                  % (stats.files, stats.changed, stats.skipped_star, stats.copied))

    if args.mode == "verify" and not all_ok:
        return 1
    if args.strict and stats.skipped_star:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
