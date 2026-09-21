#!/usr/bin/env python3
"""Checks one map note, or all of them.

Four checks, in the order they pay off: every symbol named under `## Code`
resolves in the tree, every link and `#anchor` resolves, the section set is
complete for the note's kind, and nothing restates a value another artifact
owns.

Run it on one file as you finish it. `python docs/map/check.py <file>...`,
or with no arguments for every note.
"""

import os
import re
import subprocess
import sys

MAP = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(MAP))

TERRITORY = [
    "What it is",
    "Governing decisions",
    "Design model",
    "Code",
    "Reference behaviour",
    "Cross-cutting invariants",
    "Blast radius",
    "Known holes / open",
]
INVARIANT = [
    "The fact",
    "Why it is cross-cutting",
    "Territories it holds in",
    "What a violation looks like",
    "Discovery history",
    "Where it will recur",
]

SENTINEL = "**None.**"


def _blank(text, pattern):
    out = list(text)
    for match in re.finditer(pattern, text, re.S | re.M):
        for i in range(match.start(), match.end()):
            if out[i] != "\n":
                out[i] = " "
    return "".join(out)


FENCE = r"^```.*?^```"
SPAN = r"`[^`\n]*`"


def blanked(text):
    """[text] with fenced blocks and code spans replaced by spaces.

    Offsets survive, so line numbers still line up. A document about links
    contains link-shaped text, and without this the checker reports its own
    examples.
    """
    return _blank(_blank(text, FENCE), SPAN)


def fences_only(text):
    """[text] with fenced blocks blanked but code spans kept.

    The line-number check reads this rather than [blanked]: a line number is
    written in backticks, so blanking spans makes that check unable to fail.
    A fence may hold a quoted example, so it still goes.
    """
    return _blank(text, FENCE)


def slug(heading):
    """GitHub's anchor for [heading]."""
    text = re.sub(r"[`*_]", "", heading).strip().lower()
    text = re.sub(r"[^\w\s-]", "", text)
    return re.sub(r"\s+", "-", text)


def headings_of(path):
    try:
        with open(path, encoding="utf-8") as handle:
            body = blanked(handle.read())
    except OSError:
        return None
    return {slug(m.group(1)) for m in re.finditer(r"^#+\s+(.*)$", body, re.M)}


def check(path):
    with open(path, encoding="utf-8") as handle:
        raw = handle.read()
    body = blanked(raw)
    problems = []
    rel = os.path.relpath(path, REPO).replace("\\", "/")

    # 1. Sections — the kind is the directory, since the hub has its own shape.
    parent = os.path.basename(os.path.dirname(path))
    wanted = {"territory": TERRITORY, "invariant": INVARIANT}.get(parent)
    if wanted:
        found = [m.group(1).strip() for m in re.finditer(r"^## (.*)$", body, re.M)]
        for section in wanted:
            if section not in found:
                problems.append(f"missing section: ## {section}")
        for section in found:
            if section not in wanted:
                problems.append(f"unknown section: ## {section}")

    # 2. Links and anchors.
    for match in re.finditer(r"\[[^\]]*\]\(([^)]+)\)", body):
        target = match.group(1)
        if target.startswith(("http://", "https://", "mailto:")):
            continue
        file_part, _, anchor = target.partition("#")
        if file_part:
            resolved = os.path.normpath(os.path.join(os.path.dirname(path), file_part))
            if not os.path.exists(resolved):
                problems.append(f"dead link: {target}")
                continue
        else:
            resolved = path
        if anchor:
            heads = headings_of(resolved)
            if heads is not None and anchor.lower() not in heads:
                problems.append(f"dead anchor: {target}")

    # 3. Symbols under `## Code` resolve in the tree. `**None.**` stands down.
    code = re.search(r"^## Code$(.*?)(?=^## |\Z)", body, re.S | re.M)
    if code and SENTINEL not in code.group(1):
        for line in code.group(1).splitlines():
            for name in re.findall(r"\b([A-Z][A-Za-z0-9]+(?:\.[A-Za-z_][A-Za-z0-9]*)?)", line):
                bare = name.split(".")[-1]
                hit = subprocess.run(
                    ["git", "grep", "-q", r"\b" + bare + r"\b", "--", "lib/"],
                    cwd=REPO, capture_output=True,
                )
                if hit.returncode != 0:
                    problems.append(f"symbol not in lib/: {name}")

    # 4. Line numbers are an ungated copy of something the compiler owns.
    for match in re.finditer(r"\b\w+\.dart:\d+", fences_only(raw)):
        problems.append(f"line number: {match.group(0)}")

    return rel, problems


def links_under(path, section):
    """The files [section] of [path] links to."""
    with open(path, encoding="utf-8") as handle:
        body = blanked(handle.read())
    block = re.search(rf"^## {re.escape(section)}$(.*?)(?=^## |\Z)", body, re.S | re.M)
    if not block:
        return []
    out = []
    for match in re.finditer(r"\[[^\]]*\]\(([^)#]+)[^)]*\)", block.group(1)):
        out.append(
            os.path.normpath(os.path.join(os.path.dirname(path), match.group(1)))
        )
    return out


def reciprocity():
    """Every territory an invariant claims must claim it back.

    Links alone cannot catch this. The reading protocol sends a reader to
    their territory and tells them to follow its cross-cutting section as a
    checklist, so an invariant the territory omits is invisible exactly when
    it is needed.
    """
    problems = []
    inv_dir = os.path.join(MAP, "invariant")
    if not os.path.isdir(inv_dir):
        return problems
    for name in sorted(os.listdir(inv_dir)):
        if not name.endswith(".md") or name.startswith("_"):
            continue
        inv = os.path.join(inv_dir, name)
        for terr in links_under(inv, "Territories it holds in"):
            if not os.path.exists(terr):
                continue
            back = [os.path.normpath(p) for p in links_under(terr, "Cross-cutting invariants")]
            if os.path.normpath(inv) not in back:
                problems.append(
                    f"one-way: invariant/{name} claims "
                    f"{os.path.basename(terr)}, which does not claim it back"
                )
    return problems


def main():
    targets = sys.argv[1:]
    if not targets:
        targets = [
            os.path.join(root, name)
            for root, _, names in os.walk(MAP)
            for name in names
            if name.endswith(".md") and not name.startswith("_")
        ]
    bad = 0
    for path in targets:
        rel, problems = check(path)
        if problems:
            bad += 1
            print(f"{rel}")
            for problem in problems:
                print(f"  {problem}")
    one_way = reciprocity() if not sys.argv[1:] else []
    for problem in one_way:
        print(f"  {problem}")
    print(f"{len(targets)} note(s), {bad} with problems, {len(one_way)} one-way edge(s)")
    return 1 if bad or one_way else 0


if __name__ == "__main__":
    sys.exit(main())
