extends SceneTree

# Unit tests for ui_fonts.gd: per-size font caching, the 8px floor, and the
# global theme binding Label/Button/OptionButton/PopupMenu/CheckBox.

const UI_FONTS = preload("res://scripts/ui/ui_fonts.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class FakeGame extends Reference:
	const UI_FONTS = preload("res://scripts/ui/ui_fonts.gd")
	var _font_cache = {}
	var game_font = null
	var theme = null
	func _font_at_size(px):
		return UI_FONTS.font_at_size(self, px)

func _init() -> void:
	print("== ui_fonts_test")

	# --- caching: same size returns the same instance
	var game = FakeGame.new()
	var a = UI_FONTS.font_at_size(game, 16)
	var b = UI_FONTS.font_at_size(game, 16)
	check(a == b and a != null, "the same pixel size reuses the cached font")
	check(game._font_cache.has(16), "the cache records the requested size")

	# --- sizes are distinct and integers
	var small = UI_FONTS.font_at_size(game, 12)
	check(small != a and small.size == 12, "a different size builds its own font")

	# --- floor: tiny requests clamp to 8px
	var tiny = UI_FONTS.font_at_size(game, 3)
	check(tiny.size == 8, "requests below 8px clamp to 8")
	check(UI_FONTS.font_at_size(game, 8).size == 8, "the 8px entry is cached after clamping")

	# --- init_theme binds the shared font across text controls
	game = FakeGame.new()
	UI_FONTS.init_theme(game)
	check(game.game_font != null, "init_theme installs the shared game font")
	check(game.theme != null, "init_theme installs the global theme")
	for control in ["Label", "Button", "OptionButton", "PopupMenu", "CheckBox"]:
		var bound = game.theme.get_font("font", control)
		check(bound == game.game_font, "%s is bound to the shared font" % control)

	if failures == 0:
		print("ui_fonts_test: ALL PASSED")
		quit(0)
	else:
		print("ui_fonts_test: %d FAILURES" % failures)
		quit(1)
