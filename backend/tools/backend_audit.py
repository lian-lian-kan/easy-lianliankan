#!/usr/bin/env python3
"""Static quality gate for the backend (pure stdlib, runs in CI).

Checks:
  1. function length — >45 lines ERROR, >35 WARN (mirrors the game's rule)
  2. print() ban in app/ — logging module only
  3. wildcard imports ban — explicit imports keep deps greppable
  4. bare except ban — exceptions must be typed
Exit 1 on any ERROR.
"""
import glob
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "app")
FUNC_RE = re.compile(r"^(?:async\s+)?def\s+(\w+)")
ERRORS = []
WARNS = []


def check_file(path):
    rel = os.path.relpath(path, ROOT)
    with open(path, encoding="utf-8") as fh:
        lines = fh.readlines()
    func_start = None
    func_name = ""
    for i, line in enumerate(lines, start=1):
        match = FUNC_RE.match(line)
        if match:
            if func_start is not None:
                _report_length(rel, func_name, func_start, i - 1)
            func_start, func_name = i, match.group(1)
        if re.search(r"(?<!def)print\(", line) and "print(" in line:
            ERRORS.append(f"{rel}:{i} print() found — use logging")
        if re.search(r"^\s*from\s+\S+\s+import\s+\*", line):
            ERRORS.append(f"{rel}:{i} wildcard import")
        if re.search(r"except\s*:", line):
            ERRORS.append(f"{rel}:{i} bare except — type the exception")
    if func_start is not None:
        _report_length(rel, func_name, func_start, len(lines))


def _report_length(rel, name, start, end):
    length = end - start + 1
    if length > 45:
        ERRORS.append(f"{rel}:{start} {name} spans {length} lines (max 45)")
    elif length > 35:
        WARNS.append(f"{rel}:{start} {name} spans {length} lines")


def main():
    for path in sorted(glob.glob(os.path.join(ROOT, "**", "*.py"), recursive=True)):
        check_file(path)
    for warning in WARNS:
        print(f"  WARN  {warning}")
    for error in ERRORS:
        print(f"  ERROR  {error}")
    print(f"backend_audit: {len(ERRORS)} ERROR(S), {len(WARNS)} warning(s)")
    return 1 if ERRORS else 0


if __name__ == "__main__":
    sys.exit(main())
