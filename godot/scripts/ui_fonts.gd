extends Reference

# Font factory and the global theme: the cute rounded face first, Noto for
# the glyphs it lacks, color emoji last. Fonts are cached per pixel size on
# the game node. Extracted from game.gd.

const DISPLAY_FONT = preload("res://fonts/ZCOOLKuaiLe-Regular.ttf")
const EMBEDDED_FONT = preload("res://fonts/NotoSansSC-Regular.ttf")
const EMOJI_FONT = preload("res://fonts/NotoColorEmoji.ttf")

static func font_at_size(game, px):
	px = int(max(8, px))
	if game._font_cache.has(px):
		return game._font_cache[px]
	var font = DynamicFont.new()
	# Cute rounded face first; Noto covers glyphs KuaiLe lacks, emoji last.
	font.font_data = DISPLAY_FONT if DISPLAY_FONT else EMBEDDED_FONT
	font.size = px
	font.use_filter = true
	if EMBEDDED_FONT:
		font.add_fallback(EMBEDDED_FONT)
	if EMOJI_FONT:
		font.add_fallback(EMOJI_FONT)
	game._font_cache[px] = font
	return font

static func init_theme(game):
	# Web export: bundled CJK font with color-emoji fallback so tiles render everywhere.
	game.game_font = game._font_at_size(16)

	var theme = Theme.new()
	theme.set_font("font", "Label", game.game_font)
	theme.set_font("font", "Button", game.game_font)
	theme.set_font("font", "OptionButton", game.game_font)
	theme.set_font("font", "PopupMenu", game.game_font)
	theme.set_font("font", "CheckBox", game.game_font)
	game.theme = theme
