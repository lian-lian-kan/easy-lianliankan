#!/usr/bin/env python3
"""Static consistency audit for the GDScript codebase (pure stdlib, ~1s).

Checks, in order:
  1. Thin-shell completeness  — every `game._x(...)` call made from any
     module resolves to a `func _x(` definition in game.gd.
  2. Signal connect targets   — every `connect("sig", game, "_x")` target
     resolves to a game.gd method (autoload-internal connects excluded).
  3. Orphan thin shells       — game.gd delegate shells nothing references
     anymore (warning only; they are cheap but worth pruning).
  4. Godot 4 syntax leakage   — known G4-only spellings that break GDScript 3
     (ALIGNMENT_CENTER, Control.offset_top/offset_bottom assignments).

Exit code 0 when clean, 1 when any ERROR-level finding exists.
Run:  python3 tools/shell_audit.py
"""

import glob
import re
import sys

ROOT = "."
SCRIPTS = sorted(glob.glob("scripts/*.gd"))
ALL_FILES = SCRIPTS + sorted(glob.glob("tests/*.gd")) + sorted(glob.glob("scenes/*.tscn"))

errors = []
warnings = []


def read(path):
    with open(path, encoding="utf-8", errors="ignore") as handle:
        return handle.read()


def report(level, message):
    (errors if level == "ERROR" else warnings).append(message)
    print(f"  {level}  {message}")


def main():
    sources = {path: read(path) for path in SCRIPTS}
    game_src = sources.get("scripts/game.gd", "")
    if not game_src:
        report("ERROR", "scripts/game.gd missing")
        finish()

    game_methods = set(re.findall(r"(?m)^(?:static )?func (\w+)\(", game_src))

    # --- 1) thin-shell completeness: game._x( must exist in game.gd ---
    print("== 1. thin-shell completeness (game._x calls resolve)")
    missing = {}
    for path, src in sources.items():
        if path.endswith("game.gd"):
            continue
        for m in re.finditer(r"\bgame\.(_\w+)\s*\(", src):
            name = m.group(1)
            if name not in game_methods:
                missing.setdefault(name, []).append(path)
    for name, paths in sorted(missing.items()):
        report("ERROR", f"game.{name}() called but not defined in game.gd <- {','.join(paths)}")
    if not missing:
        print("  ok  every game._x call resolves")

    # --- 2) signal connect targets on game ---
    print("== 2. signal connect targets resolve")
    connect_bad = []
    for path, src in sources.items():
        for m in re.finditer(r'connect\("[^"]+",\s*game,\s*"(_\w+)"', src):
            method = m.group(1)
            if method not in game_methods:
                connect_bad.append((path, method))
        for m in re.finditer(r'connect\("[^"]+",\s*self,\s*"(_\w+)"', src):
            method = m.group(1)
            owner_methods = set(re.findall(r"(?m)^(?:static )?func (\w+)\(", src))
            if method not in owner_methods:
                connect_bad.append((path, method))
    for path, method in sorted(connect_bad):
        report("ERROR", f"connect target '{method}' not defined (in {path})")
    if not connect_bad:
        print("  ok  every connect target exists on its owner")

    # --- 3) orphan thin shells ---
    print("== 3. orphan thin shells (defined, never referenced)")
    all_text = "".join(sources.values()) + "".join(read(p) for p in ALL_FILES if p.endswith((".tscn", ".gd")))
    orphan = []
    for m in re.finditer(r"(?m)^func (_\w+)\(", game_src):
        name = m.group(1)
        # definition line itself accounts for one occurrence
        if len(re.findall(re.escape(name), all_text)) <= 1:
            orphan.append(name)
    for name in sorted(orphan):
        warnings.append(f"orphan shell {name}")
    if orphan:
        for name in sorted(orphan):
            print(f"  WARN  {name}")
    else:
        print("  ok  no orphan shells")

    # --- 4) Godot 4 syntax leakage ---
    print("== 4. Godot 4 syntax leakage")
    g4_patterns = [
        (r"\bALIGNMENT_CENTER\b", "BoxContainer.ALIGN_CENTER is the Godot 3 name"),
        (r"\.offset_top\s*=", "Godot 3 Control uses margin_top"),
        (r"\.offset_bottom\s*=", "Godot 3 Control uses margin_bottom"),
    ]
    leaks = []
    for path, src in sources.items():
        for pattern, why in g4_patterns:
            for m in re.finditer(pattern, src):
                line_no = src[: m.start()].count("\n") + 1
                leaks.append(f"{path}:{line_no}  {why}")
    for leak in leaks:
        report("ERROR", leak)
    if not leaks:
        print("  ok  no Godot 4 syntax leakage")

    finish()


def finish():
    if errors:
        print(f"\nshell_audit: {len(errors)} ERROR(S)")
        sys.exit(1)
    print("\nshell_audit: clean")
    sys.exit(0)


main()
