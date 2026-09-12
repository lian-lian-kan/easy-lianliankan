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
  6. Scale gates              — function/file length ceilings so quality does
     not erode as the codebase grows (game.gd exempt from the file gate:
     it is the documented thin-shell composition root).

Exit code 0 when clean, 1 when any ERROR-level finding exists.
Run:  python3 tools/shell_audit.py
"""

import glob
import re
import sys

ROOT = "."
# Scripts live in domain subdirs (board/modes/session/ui/pages/content);
# game.gd and the audio_manager autoload stay at the scripts/ root.
SCRIPTS = sorted(glob.glob("scripts/**/*.gd", recursive=True))
ALL_FILES = SCRIPTS + sorted(glob.glob("tests/*.gd")) + sorted(glob.glob("scenes/*.tscn"))

FUNC_LEN_WARN = 35
FUNC_LEN_MAX = 45
FILE_LEN_WARN = 650
FILE_LEN_MAX = 800
FILE_LEN_EXEMPT = {"scripts/game.gd"}
# Ratchet: legacy offenders registered with their current span at gate
# introduction (2026-09-12). They may shrink freely; any growth, and any NEW
# function over FUNC_LEN_MAX, is an ERROR. Treat entries as refactor rounds
# land and delete the line when the function is finally split.
FUNC_LEN_RATCHET = {
    "scripts/board/board_engine.gd::find_path": 60,
    "scripts/board/board_view.gd::_refresh_board_visuals": 70,
    "scripts/modes/tile_match.gd::build_view": 67,
    "scripts/pages/page_router.gd::_build_stats": 50,
    "scripts/session/game_input.gd::_on_tile_pressed": 82,
    "scripts/session/game_input.gd::_on_memory_tile_pressed": 59,
    "scripts/session/game_input.gd::_unhandled_input": 62,
    "scripts/session/hud_timers.gd::_build_timers": 47,
    "scripts/session/powerups.gd::_use_power_up": 52,
    "scripts/session/progression.gd::normalize_progress": 79,
    "scripts/session/progression.gd::apply_update": 117,
    "scripts/session/session.gd::_reset_level_session": 110,
    "scripts/session/session.gd::_settle_campaign_clear": 51,
    "scripts/ui/home_screen.gd::_build_controls_flow": 51,
    "scripts/ui/home_screen.gd::_build_board_area": 49,
    "scripts/ui/hud_layout.gd::update_layout": 154,
    "scripts/ui/ui_panels.gd::_onboarding_panel": 51,
    "scripts/ui/ui_panels.gd::_settings_panel": 63,
    "scripts/ui/ui_panels.gd::_pause_panel": 59,
}

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
        for m in re.finditer(r'(?m)^const (\w+) = preload\("res://((?:scripts|tests)/[\w./]+)"\)', src):
            alias, target = m.group(1), m.group(2)
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

    # --- 6) scale gates: length ceilings so growth cannot erode quality ---
    print("== 6. scale gates (function/file length)")
    gate_bad = 0

    def check_span(path, label, start, body):
        ratcheted = FUNC_LEN_RATCHET.get(f"{path}::{label}")
        if ratcheted is not None:
            if body > ratcheted:
                report("ERROR", f"{path}:{start} {label} spans {body} lines (ratchet {ratcheted}; split it, never grow it)")
                return 1
            if body < ratcheted:
                print(f"  ok-shrunk  {label} in {path} now {body} lines (ratchet {ratcheted}) — lower the entry")
            return 0
        if body > FUNC_LEN_MAX:
            report("ERROR", f"{path}:{start} {label} spans {body} lines (max {FUNC_LEN_MAX})")
            return 1
        if body > FUNC_LEN_WARN:
            warnings.append(f"{path}:{start} {label} spans {body} lines")
            print(f"  WARN  {label} in {path} spans {body} lines")
        return 0

    for path in SCRIPTS:
        src = read(path)
        lines = src.split("\n")
        if len(lines) > FILE_LEN_MAX and path not in FILE_LEN_EXEMPT:
            report("ERROR", f"{path} is {len(lines)} lines (max {FILE_LEN_MAX})")
            gate_bad += 1
        elif len(lines) > FILE_LEN_WARN and path not in FILE_LEN_EXEMPT:
            warnings.append(f"{path} is {len(lines)} lines (warn at {FILE_LEN_WARN})")
            print(f"  WARN  {path} is {len(lines)} lines")
        cur = None
        cur_start = 0
        cur_indent = 0
        body = 0
        for i, ln in enumerate(lines):
            m = re.match(r"^(\s*)(?:static )?func\s+\w+\(", ln)
            if m:
                if cur is not None:
                    gate_bad += check_span(path, cur, cur_start, body)
                cur, cur_start, cur_indent, body = ln.strip().split("(")[0].split()[-1], i + 1, len(m.group(1)), 0
            elif cur is not None:
                if ln.strip() and not ln.strip().startswith("#"):
                    indent = len(ln) - len(ln.lstrip())
                    if indent <= cur_indent:
                        gate_bad += check_span(path, cur, cur_start, body)
                        cur = None
                    else:
                        body += 1
        if cur is not None:
            gate_bad += check_span(path, cur, cur_start, body)
    if gate_bad == 0:
        print(f"  ok  all functions <={FUNC_LEN_WARN} lines and files <={FILE_LEN_WARN} lines")

    finish()


def finish():
    if errors:
        print(f"\nshell_audit: {len(errors)} ERROR(S)")
        sys.exit(1)
    print("\nshell_audit: clean")
    sys.exit(0)


main()
