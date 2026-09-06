#!/usr/bin/env python3
"""Subset the bundled fonts to the characters the game actually uses.

Full sources (tens of thousands of glyphs) ship in fonts/full/ (gitignored);
only the subsets under fonts/ are packed into the exported .pck. The game
links them as a fallback chain: ZCOOL KuaiLe (cute display face) ->
NotoSansSC (full CJK coverage) -> NotoColorEmoji.

Coverage policy (fail loudly rather than ship tofu):
  - Sans / display subsets: every scanned char below U+1F000, plus ASCII, CJK
    punctuation, fullwidth forms, and the symbol blocks (arrows / shapes /
    dingbats) so UI glyphs never depend on the emoji fallback. ZCOOL KuaiLe
    only CONTAINS a few thousand glyphs, so for it we subset the intersection
    with its cmap (best effort) and REQUIRE coverage of the core UI text;
    anything else silently falls back to NotoSansSC at runtime.
  - Emoji subset: every scanned char in the emoji blocks, plus ZWJ / VS16 /
    keycap connectors, skin-tone modifiers, regional indicators, and the
    ASCII digits needed by keycap ligatures.
Chars found in the symbol blocks go into BOTH text subsets; whichever font
wins the lookup, the glyph exists.

Regenerating after adding new in-game text or icons:
  python3 tools/subset_fonts.py
Full-font sources (place into godot/fonts/full/):
  NotoSansSC-Regular.ttf  https://fonts.google.com/noto (Noto Sans SC, weight 400)
  NotoColorEmoji.ttf      https://github.com/googlefonts/noto-emoji
  ZCOOLKuaiLe-Regular.ttf https://github.com/google/fonts/tree/main/ofl/zcoolkuaile
"""

import os
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

GODOT_DIR = Path(__file__).resolve().parent.parent
FONTS_DIR = GODOT_DIR / "fonts"
FULL_DIR = FONTS_DIR / "full"
SCAN_EXTS = {".gd", ".json", ".godot"}

# Per-font guard thresholds: the trap this guards against is bootstrapping a
# worktree by copying the committed SUBSET as the "full" font, which silently
# produces subset-of-subset tofu for any newly added text. Thresholds sit
# clearly between real full sizes and subset sizes.
FONTS = [
    {"name": "NotoSansSC-Regular.ttf", "min_full_bytes": 5_000_000, "role": "sans"},
    {"name": "NotoColorEmoji.ttf", "min_full_bytes": 5_000_000, "role": "emoji"},
    {"name": "ZCOOLKuaiLe-Regular.ttf", "min_full_bytes": 1_000_000, "role": "display"},
]
# Chars the core UI must render in the cute face (not fall back to Noto),
# as a hard gate on the display subset.
DISPLAY_CORE_TEXT = (
    "连连看每日挑战限时无尽盲盒记忆模式开始返回继续重玩下一关暂停设置成就玩法"
    "提示自动洗牌放大镜时光沙漏炸弹彩虹分数时间目标连击最佳剩余关卡 Progress "
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
)


def collect_source_chars():
    chars = set()
    scanned = 0
    for p in sorted(GODOT_DIR.rglob("*")):
        if not p.is_file() or p.suffix not in SCAN_EXTS:
            continue
        if ".import" in p.parts or FULL_DIR in p.parents:
            continue
        chars.update(p.read_text(encoding="utf-8"))
        scanned += 1
    return chars, scanned


def in_symbol_blocks(cp):
    return (0x2190 <= cp <= 0x2BFF) or cp in (0x2032, 0x2033, 0x203C, 0x2049)


def build_sans_text(source_chars):
    cps = set(ord(c) for c in source_chars if ord(c) < 0x1F000)
    # Safety net so runtime-composed UI text always has glyphs even if a
    # literal never appears in the scanned sources.
    cps.update(range(0x20, 0x7F))            # ASCII
    cps.update(range(0x3000, 0x3040))        # CJK punctuation
    cps.update(range(0xFF01, 0xFF5F))        # fullwidth forms
    cps.update(range(0x2010, 0x2028))        # dashes, quotes, ellipsis
    cps.update((0x00B7, 0x00D7, 0x00F7, 0x00A0))
    # Every scanned symbol-block char, doubled into the sans set.
    cps.update(ord(c) for c in source_chars if in_symbol_blocks(ord(c)))
    return "".join(chr(cp) for cp in sorted(cps))


def build_emoji_text(source_chars):
    cps = set(ord(c) for c in source_chars if ord(c) >= 0x1F000)
    cps.update(ord(c) for c in source_chars if in_symbol_blocks(ord(c)))
    cps.update((0xFE0F, 0x200D, 0x20E3))     # VS16, ZWJ, keycap cap
    cps.update(range(0x1F1E6, 0x1F200))      # regional indicators (flags)
    cps.update(range(0x1F3FB, 0x1F400))      # skin-tone modifiers
    cps.update(ord(c) for c in "0123456789#*")  # keycap bases
    return "".join(chr(cp) for cp in sorted(cps))


def font_cmap(path):
    font = TTFont(str(path), lazy=True)
    cmap = set()
    for table in font["cmap"].tables:
        cmap.update(table.cmap.keys())
    font.close()
    return cmap


def subset_font(src, dst, text):
    options = subset.Options()
    options.layout_features = ["*"]
    options.notdef_outline = True
    options.glyph_names = False
    options.name_IDs = [1, 2, 3, 4, 6]
    font = subset.load_font(str(src), options)
    subsetter = subset.Subsetter(options)
    subsetter.populate(text=text)
    subsetter.subset(font)
    tmp = dst.with_suffix(".subset.tmp")
    subset.save_font(font, str(tmp), options)
    font.close()
    os.replace(tmp, dst)
    return dst.stat().st_size


def bootstrap_full(full, live, min_full_bytes):
    if full.exists():
        return
    if not live.exists():
        print("FAIL: missing both %s and %s" % (full, live))
        sys.exit(1)
    full.write_bytes(live.read_bytes())
    if full.stat().st_size < min_full_bytes:
        print("FAIL: %s looks like an already-subsetted font (%d bytes); "
              "put the genuine full font there first" % (full, full.stat().st_size))
        sys.exit(1)


def main():
    source_chars, scanned = collect_source_chars()
    sans_text = build_sans_text(source_chars)
    emoji_text = build_emoji_text(source_chars)
    role_text = {"sans": sans_text, "emoji": emoji_text}

    sans_cps = set(ord(c) for c in sans_text)
    emoji_cps = set(ord(c) for c in emoji_text)
    uncovered = [
        c for c in source_chars
        if ord(c) not in sans_cps and ord(c) not in emoji_cps
        and c not in "\n\r\t"
    ]
    if uncovered:
        print("FAIL: source chars not covered by any subset: %r" % uncovered)
        sys.exit(1)

    FULL_DIR.mkdir(parents=True, exist_ok=True)
    # .gdignore keeps the full originals out of res://, so Godot never
    # imports or packs them; only the subsets under fonts/ ship.
    (FULL_DIR / ".gdignore").touch()

    for cfg in FONTS:
        name = cfg["name"]
        full = FULL_DIR / name
        live = FONTS_DIR / name
        bootstrap_full(full, live, cfg["min_full_bytes"])
        if full.stat().st_size < cfg["min_full_bytes"]:
            print("FAIL: %s looks like an already-subsetted font (%d bytes); "
                  "put the genuine full font there first" % (full, full.stat().st_size))
            sys.exit(1)

        text = role_text.get(cfg["role"], sans_text)
        before = full.stat().st_size
        if cfg["role"] == "display":
            # Best effort: keep only the chars this face actually contains.
            covered = font_cmap(full)
            wanted = set(ord(c) for c in text)
            missing = sorted(wanted - covered)
            core_missing = [c for c in DISPLAY_CORE_TEXT if ord(c) in set(missing)]
            if core_missing:
                print("FAIL: display font lacks core UI glyphs: %r" % "".join(core_missing))
                sys.exit(1)
            text = "".join(chr(cp) for cp in sorted(wanted & covered))
            print("%s: %d of %d requested chars in face (%d fall back to Noto)"
                  % (name, len(wanted) - len(missing), len(wanted), len(missing)))
        after = subset_font(full, live, text)
        print("%s: %.1fMB -> %.1fMB" % (name, before / 1e6, after / 1e6))

    # The emoji font is CBDT/CBLC bitmap; make sure the color tables survived.
    emoji_font = TTFont(str(FONTS_DIR / "NotoColorEmoji.ttf"))
    missing_tables = [t for t in ("CBDT", "CBLC", "cmap") if t not in emoji_font]
    emoji_font.close()
    if missing_tables:
        print("FAIL: emoji subset lost tables: %s" % missing_tables)
        sys.exit(1)

    print("scanned %d files, %d source chars; sans=%d cps, emoji=%d cps"
          % (scanned, len(source_chars), len(sans_cps), len(emoji_cps)))
    print("OK")


if __name__ == "__main__":
    main()
