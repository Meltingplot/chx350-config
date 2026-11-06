#!/usr/bin/env python3
"""Find flow macros that collide in the CHX 350 UI, without a machine.

A message box carries no file or line. The UI (DWC plugin CHX350,
src/plugins/CHX350/flows/) finds the step of an open box by its title and S
mode alone, over every indexed file, and shows that step's Markdown instead of
the box's P text (findStep, store.ts).  So these go wrong:

* the same documented title twice in one file: parse.ts drops the second ;;
  block, whatever the modes are
* the same documented title in two files with overlapping modes: a box can show
  the other file's step
* a plain M291 (no ;; block) with the title of a documented step and an
  overlapping mode: it shows that step's text instead of its own P text
* two flows with the same front matter title: two tiles the operator cannot
  tell apart

Modes overlap when they are equal or when one is an expression (S{...}), which
is only known at run time.  Findings the modes do tell apart, and two flows
sharing an order on one page (the UI then sorts them by title), are notes: they
do not fail the check unless --strict is given.  The Service page warns about
the title notes as well, because a UI build older than the mode match (DWC
996717f3) goes by the title alone.

Two plain M291 with the same title are fine: neither has a step to be mistaken
for.  A computed title (R{...}) is only known at run time and cannot be checked;
the summary counts them.

The parser follows parse.ts line by line and the file selection follows scan()
in store.ts.  When those change, change this too.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

# Limits and file types of the UI's index (store.ts)
MAX_FILE_SIZE = 256 * 1024
MAX_DEPTH = 4
SKIPPED_EXTENSIONS = re.compile(
    r"\.(png|jpe?g|webp|gif|svg|bmp|ico|bin|uf2|zip|csv|json|html?|css|js|map|txt|md|log)$",
    re.IGNORECASE)
FLOW_PAGES = ("start", "job", "calibrate", "service")
DEFAULT_ORDER = 100.0

FRONT_MATTER_FENCE = re.compile(r"^\s*;\s?---\s*$")
DOC_LINE = re.compile(r"^\s*;;")
LINE_NUMBER = re.compile(r"^N\d+\s*", re.IGNORECASE)
M291 = re.compile(r"^M291(?![\d.])", re.IGNORECASE)
META_KEY = re.compile(r"^(title|page|order)\s*:\s*(.*)$")


@dataclass
class Prompt:
    path: str
    line: int
    title: str | None   # None: computed, R{...}; "": no R, the box has no title
    mode: int | None    # None: computed, S{...}
    documented: bool


@dataclass
class Flow:
    path: str
    title: str
    pages: list[str]
    order: float


# --------------------------------------------------------------------------
# Parser, see parse.ts
# --------------------------------------------------------------------------

def split_comment(line: str) -> str:
    """The code part of a line: a ';' inside a string starts no comment."""
    in_string = False
    for i, c in enumerate(line):
        if c == '"':
            in_string = not in_string
        elif c == ";" and not in_string:
            return line[:i]
    return line


def normalise_code(code: str) -> str:
    """Strip indentation, a deployed line number and a checksum or CRC."""
    text = LINE_NUMBER.sub("", code.strip())
    in_string = False
    depth = 0
    for i, c in enumerate(text):
        if c == '"':
            in_string = not in_string
        elif not in_string:
            if c == "{":
                depth += 1
            elif c == "}":
                depth = max(0, depth - 1)
            elif c == "*" and depth == 0:
                text = text[:i]
                break
    return text.strip()


def parse_parameters(args: str) -> dict[str, tuple[str, str]]:
    """Parameters as letter -> (kind, value), kind: string, expression or bare."""
    result = {}
    i = 0
    n = len(args)
    while i < n:
        c = args[i]
        if not (c.isascii() and c.isalpha()):
            i += 1
            continue
        letter = c.upper()
        i += 1
        if i < n and args[i] == '"':
            value = []
            i += 1
            while i < n:
                if args[i] == '"':
                    if i + 1 < n and args[i + 1] == '"':
                        value.append('"')
                        i += 2
                        continue
                    i += 1
                    break
                value.append(args[i])
                i += 1
            result[letter] = ("string", "".join(value))
        elif i < n and args[i] == "{":
            start = i
            depth = 0
            in_string = False
            while i < n:
                ch = args[i]
                if ch == '"':
                    in_string = not in_string
                elif not in_string:
                    if ch == "{":
                        depth += 1
                    elif ch == "}":
                        depth -= 1
                        if depth == 0:
                            i += 1
                            break
                i += 1
            result[letter] = ("expression", args[start:i])
        else:
            start = i
            while i < n and args[i] in "-+0123456789.:":
                i += 1
            result[letter] = ("bare", args[start:i])
    return result


def yaml_scalar(text: str) -> str:
    """The value of a one-line YAML scalar, the only form the flows use."""
    text = text.strip()
    match = re.match(r'"((?:[^"\\]|\\.)*)"', text)
    if match:
        return re.sub(r"\\(.)", r"\1", match.group(1))
    match = re.match(r"'((?:[^']|'')*)'", text)
    if match:
        return match.group(1).replace("''", "'")
    return re.split(r"\s#", text, maxsplit=1)[0].strip()


def parse_front_matter(body: list[str], path: str) -> Flow | None:
    """Title, pages and order; None without a title, as in the UI.

    Reads flat 'key: value' lines, 'page: [a, b]' and a '- a' list below 'page:'.
    That is all a flow's front matter needs, and it keeps the tool stdlib only.
    """
    title = None
    pages = []
    order = DEFAULT_ORDER
    in_page_list = False
    for line in body:
        item = re.match(r"^\s*-\s+(.*)$", line)
        if in_page_list and item:
            pages.append(yaml_scalar(item.group(1)))
            continue
        in_page_list = False
        match = META_KEY.match(line)
        if not match:
            continue
        key, value = match.groups()
        value = value.strip()
        if key == "title":
            title = yaml_scalar(value).strip()
        elif key == "order":
            try:
                order = float(yaml_scalar(value))
            except ValueError:
                pass
        elif value.startswith("["):
            pages = [yaml_scalar(p) for p in value.strip("[] ").split(",") if p.strip()]
        elif value:
            pages = [yaml_scalar(value)]
        else:
            in_page_list = True
    if not title:
        return None
    pages = [p for p in FLOW_PAGES if p in pages]
    return Flow(path, title, pages, order)


def parse_file(text: str, path: str) -> tuple[Flow | None, list[Prompt]]:
    lines = [line[:-1] if line.endswith("\r") else line for line in text.split("\n")]
    index = 0
    while index < len(lines) and not lines[index].strip():
        index += 1

    # Front matter: '; ---' on the first line that is not blank, closed by the next '; ---'
    flow = None
    if index < len(lines) and FRONT_MATTER_FENCE.match(lines[index]):
        start = index
        body = []
        closed = False
        index += 1
        while index < len(lines):
            line = lines[index]
            if FRONT_MATTER_FENCE.match(line):
                closed = True
                index += 1
                break
            trimmed = line.lstrip()
            if trimmed and not trimmed.startswith(";"):
                break
            body.append(re.sub(r"^ ", "", re.sub(r"^;", "", trimmed)))
            index += 1
        if closed:
            flow = parse_front_matter(body, path)
        else:
            index = start + 1

    prompts = []
    documented = False
    for number, line in enumerate(lines[index:], index + 1):
        if DOC_LINE.match(line):
            documented = True
            continue
        code = normalise_code(split_comment(line))
        if not code:
            # Blank line or plain comment: a pending block stays attached to the next code line
            continue
        match = M291.match(code)
        if match:
            params = parse_parameters(code[match.end():])
            kind, title = params.get("R", ("string", ""))
            kind_s, value_s = params.get("S", ("bare", "1"))    # no S: 1, as in RRF
            mode = int(value_s) if kind_s == "bare" and value_s.isdigit() else None
            prompts.append(Prompt(path, number, title if kind == "string" else None, mode, documented))
        documented = False
    return flow, prompts


# --------------------------------------------------------------------------
# Which files the UI reads, see scan() in store.ts
# --------------------------------------------------------------------------

def visit(directory: Path, depth: int):
    if not directory.is_dir():
        return
    for item in sorted(directory.iterdir()):
        if item.is_dir():
            if depth < MAX_DEPTH:
                yield from visit(item, depth + 1)
        elif not SKIPPED_EXTENSIONS.search(item.name) and item.stat().st_size <= MAX_FILE_SIZE:
            yield item


def indexed_files(root: Path):
    for directory in ("macros", "sys/meltingplot", "sys/overrides/flows"):
        yield from visit(root / directory, 0)
    # The system macros raise prompts too, but only the files directly in sys/ are indexed
    yield from visit(root / "sys", MAX_DEPTH)


# --------------------------------------------------------------------------
# The checks
# --------------------------------------------------------------------------

def modes_overlap(a: Prompt, b: Prompt) -> bool:
    return a.mode is None or b.mode is None or a.mode == b.mode


def check_title(places: list[Prompt]) -> tuple[list[str], bool]:
    """What is wrong with the prompts of one title, and whether that is an error."""
    steps = [p for p in places if p.documented]
    if not steps or len(places) == 1:
        return [], False

    paths = [p.path for p in steps]
    twice = len(set(paths)) < len(paths)
    other_file = shared_plain = False
    for step in steps:
        for other in places:
            if other is step or not modes_overlap(step, other):
                continue
            if not other.documented:
                shared_plain = True
            elif other.path != step.path:
                other_file = True

    reasons = []
    if twice:
        reasons.append("documented twice in one file, the UI drops the second block")
    if other_file:
        reasons.append("documented in several files, a box can show the other file's step")
    if shared_plain:
        reasons.append("a plain M291 shows the documented step's text instead of its own")
    if reasons:
        return reasons, True
    return ["only the S mode tells these apart"], False


def check_prompts(prompts: list[Prompt]) -> tuple[list[str], list[str]]:
    by_title = defaultdict(list)
    for prompt in prompts:
        # A blank title is no step (parse.ts), and neither is a computed one
        if prompt.title is not None and prompt.title.strip():
            by_title[prompt.title].append(prompt)

    errors = []
    notes = []
    for title, places in by_title.items():
        reasons, is_error = check_title(places)
        if not reasons:
            continue
        width = max(len(f"{p.path}:{p.line}") for p in places)
        block = [f'title "{title}": ' + "; ".join(reasons)]
        for p in places:
            mode = "S{...}" if p.mode is None else f"S{p.mode}"
            kind = "documented" if p.documented else "plain"
            block.append(f"    {p.path}:{p.line}".ljust(width + 6) + f"{mode}  {kind}")
        (errors if is_error else notes).append("\n".join(block))
    return errors, notes


def check_flows(flows: list[Flow]) -> tuple[list[str], list[str]]:
    by_title = defaultdict(list)
    by_slot = defaultdict(list)
    for flow in flows:
        by_title[flow.title].append(flow)
        for page in flow.pages:
            by_slot[(page, flow.order)].append(flow)

    errors = []
    for title, same in by_title.items():
        if len(same) > 1:
            errors.append("\n".join([f'flow title "{title}": two tiles the operator cannot tell apart']
                                    + [f"    {f.path}" for f in same]))
    notes = []
    for (page, order), same in by_slot.items():
        if len(same) > 1:
            notes.append("\n".join([f'page "{page}", order {order:g}: the UI sorts these by title']
                                   + [f"    {f.path} ({f.title})" for f in same]))
    return errors, notes


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        description="Find M291 titles and flow tiles that collide in the CHX 350 UI.")
    ap.add_argument("root", nargs="?", type=Path, default=Path(__file__).resolve().parent.parent,
                    help="tree to check, holding macros/ and sys/ (default: this repository)")
    ap.add_argument("--strict", action="store_true", help="fail on notes as well")
    args = ap.parse_args(argv)

    if not (args.root / "macros").is_dir() or not (args.root / "sys").is_dir():
        print(f"error: {args.root} holds no macros/ and sys/", file=sys.stderr)
        return 2

    flows = []
    prompts = []
    for path in indexed_files(args.root):
        text = path.read_bytes().decode("utf-8", errors="replace")
        flow, found = parse_file(text, path.relative_to(args.root).as_posix())
        if flow is not None:
            flows.append(flow)
        prompts.extend(found)

    prompt_errors, prompt_notes = check_prompts(prompts)
    flow_errors, flow_notes = check_flows(flows)
    errors = prompt_errors + flow_errors
    notes = prompt_notes + flow_notes

    for entry in errors:
        print("error: " + entry)
    for entry in notes:
        print("note: " + entry)

    documented = sum(1 for p in prompts if p.documented)
    computed = sum(1 for p in prompts if p.title is None)
    print(f"{len(flows)} flows, {len(prompts)} M291 ({documented} documented, "
          f"{computed} with a computed title, not checked): "
          f"{len(errors)} collisions, {len(notes)} notes")
    return 1 if errors or (args.strict and notes) else 0


if __name__ == "__main__":
    sys.exit(main())
