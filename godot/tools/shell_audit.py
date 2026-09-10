#!/usr/bin/env python3
"""Static consistency audit for the GDScript codebase (pure stdlib, ~1s).

Checks, in order:
  1. Thin-shell completeness  — every `game._x(...)` call made from any
     module resolves to a `func _x(` definition in game.gd.
  2. Signal connect targets   — every `connect("sig", game, "_x")` target
     resolves to a game.gd method (autoload-internal connects excluded).
  3. Orphan thin shells       — game.gd delegate shells nothing references
     anymore (warning only; they are cheap but worth pruning).
  3.5 Orphan member vars      — game.gd vars nothing references (warning only).
  4. Godot 4 syntax leakage   — known G4-only spellings that break GDScript 3
     (ALIGNMENT_CENTER, Control.offset_top/offset_bottom assignments).
  5. Cross-module calls       — every `ALIAS.fn(...)` / `game.ALIAS.fn(...)`
     call resolves to a function in the preloaded target script (the class of
     breakage behind the tile_match.new_round startup crash).

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

    # --- 3.5) orphan member vars in game.gd ---
    print("== 3.5. orphan member vars (declared in game.gd, never referenced)")
    others_text = ""
    for path, src in sources.items():
        if not path.endswith("game.gd"):
            others_text += src
    for f in glob.glob("tests/*.gd") + glob.glob("scenes/*.tscn"):
        others_text += read(f)
    game_src = sources["scripts/game.gd"]
    orphan_vars = []
    for m in re.finditer(r"(?m)^var (\w+)", game_src):
        name = m.group(1)
        external = len(re.findall(r"\b" + name + r"\b", others_text))
        internal = len(re.findall(r"\b" + name + r"\b", game_src))
        if external == 0 and internal <= 1:
            orphan_vars.append(name)
    if orphan_vars:
        for name in sorted(orphan_vars):
            warnings.append(f"orphan member var {name}")
            print(f"  WARN  {name}")
    else:
        print("  ok  no orphan member vars")

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

    # --- 5) cross-module calls resolve ---
    # Aliases are file-scoped consts, so each file's own preload map is used.
    print("== 5. cross-module calls resolve")
    all_gd = SCRIPTS + sorted(glob.glob("tests/*.gd"))
    module_funcs = {}
    for path in all_gd:
        module_funcs[path] = set(re.findall(r"(?m)^(?:static )?func (\w+)\(", read(path)))
    dangling = []
    for path in all_gd:
        src = read(path)
        # Round A: file-scoped aliases (`ALIAS.fn(`), declared in this file.
        for m in re.finditer(r'(?m)^const (\w+) = preload\("res://(scripts|tests)/([\w.]+)"\)', src):
            alias, target = m.group(1), f"{m.group(2)}/{m.group(3)}"
            if target not in module_funcs:
                continue
            for call in re.finditer(r"\b" + alias + r"\.(\w+)\s*\(", src):
                fn = call.group(1)
                if fn in ("new", "instance"):
                    continue
                if fn not in module_funcs[target]:
                    line_no = src[: call.start()].count("\n") + 1
                    dangling.append(f"{path}:{line_no}  {alias}.{fn}() missing in {target}")
        # Round B: game-member aliases (`game.ALIAS.fn(`), declared in game.gd.
        if path.endswith("game.gd"):
            continue
        for m in re.finditer(r'(?m)^const (\w+) = preload\("res://([\w./]+)"\)', game_src):
            alias, target = m.group(1), m.group(2)
            if target not in module_funcs:
                continue
            for call in re.finditer(r"\bgame\." + alias + r"\.(\w+)\s*\(", src):
                fn = call.group(1)
                if fn in ("new", "instance"):
                    continue
                if fn not in module_funcs[target]:
                    line_no = src[: call.start()].count("\n") + 1
                    dangling.append(f"{path}:{line_no}  game.{alias}.{fn}() missing in {target}")
    for item in sorted(set(dangling)):
        report("ERROR", f"dangling cross-module call: {item}")
    if not dangling:
        print("  ok  every cross-module call resolves")

    finish()


def finish():
    if errors:
        print(f"\nshell_audit: {len(errors)} ERROR(S)")
        sys.exit(1)
    print("\nshell_audit: clean")
    sys.exit(0)


main()
