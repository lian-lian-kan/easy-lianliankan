#!/usr/bin/env python3
"""Subset the bundled Noto fonts to the characters the game actually uses.

The full NotoSansSC-Regular.ttf (16MB) and NotoColorEmoji.ttf (10MB) ship
with tens of thousands of glyphs; the game renders fewer than 700 distinct
characters. Subsetting them keeps the exported .pck small enough for mobile
first-load, while the full originals stay in fonts/full/ (gitignored) for
regeneration.

Coverage policy (fail loudly rather than ship tofu):
  - Sans subset:  every scanned char below U+1F000, plus ASCII, CJK
    punctuation, fullwidth forms, and the symbol blocks (arrows / shapes /
    dingbats) so UI glyphs never depend on the emoji fallback.
  - Emoji subset: every scanned char in the emoji blocks, plus ZWJ / VS16 /
    keycap connectors, skin-tone modifiers, regional indicators, and the
    ASCII digits needed by keycap ligatures.
Chars found in the symbol blocks go into BOTH subsets; whichever font wins
the lookup, the glyph exists.

Regenerating after adding new in-game text or icons:
  python3 tools/subset_fonts.py
Full-font sources (place into godot/fonts/full/):
  NotoSansSC-Regular.ttf  https://fonts.google.com/noto (Noto Sans SC, weight 400)
  NotoColorEmoji.ttf      https://github.com/googlefonts/noto-emoji
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


def main():
    source_chars, scanned = collect_source_chars()
    sans_text = build_sans_text(source_chars)
    emoji_text = build_emoji_text(source_chars)

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
    # .gdignore keeps the 27MB originals out of res://, so Godot never
    # imports or packs them; only the subsets under fonts/ ship.
    (FULL_DIR / ".gdignore").touch()
    for name in ("NotoSansSC-Regular.ttf", "NotoColorEmoji.ttf"):
        full = FULL_DIR / name
        live = FONTS_DIR / name
        if not full.exists():
            if not live.exists():
                print("FAIL: missing both %s and %s" % (full, live))
                sys.exit(1)
            full.write_bytes(live.read_bytes())
        if full.stat().st_size < 5 * 1000 * 1000:
            print("FAIL: %s looks like an already-subsetted font (%d bytes); "
                  "put the genuine full font there first" % (full, full.stat().st_size))
            sys.exit(1)
        text = sans_text if "Sans" in name else emoji_text
        before = full.stat().st_size
        after = subset_font(full, live, text)
        print("%s: %.1fMB -> %.1fMB" % (name, before / 1e6, after / 1e6))

    # The emoji font is CBDT/CBLC bitmap; make sure the color tables survived.
    emoji_font = TTFont(str(FONTS_DIR / "NotoColorEmoji.ttf"))
    missing = [t for t in ("CBDT", "CBLC", "cmap") if t not in emoji_font]
    emoji_font.close()
    if missing:
        print("FAIL: emoji subset lost tables: %s" % missing)
        sys.exit(1)

    print("scanned %d files, %d source chars; sans=%d cps, emoji=%d cps"
          % (scanned, len(source_chars), len(sans_cps), len(emoji_cps)))
    print("OK")


if __name__ == "__main__":
    main()
