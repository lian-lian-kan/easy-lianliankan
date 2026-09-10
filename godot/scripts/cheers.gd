extends Reference

# Combo cheers: the little surprises that make every streak feel fresh.
# Praise lines are drawn from tiered pools through a shuffled deck, so the
# player keeps hearing new phrasing for dozens of matches before a repeat.
# Streak milestones pay a small blossom bonus once per round — an incentive
# spike to chase, not a farmable income.

# Tiered praise pools (combo >= key). 36 lines total; keep each line short
# enough for the burst label (<= 8 glyphs).
const TIERS = [
	{"min": 10, "lines": ["传说降临！", "神话再现", "解除封印！", "最强大脑", "永恒之火", "棋盘之神"]},
	{"min": 8, "lines": ["天神下凡", "无敌了！", "人形消除机", "这就是高手", "棋盘在你手里", "史诗级连击", "挡不住了"]},
	{"min": 6, "lines": ["五连爆发！", "势不可挡", "全场瞩目", "闪电手！", "连击机器", "太轻松了吧", "火花四溅"]},
	{"min": 4, "lines": ["连成串了", "停不下来", "火力全开", "行云流水", "眼疾手快", "这波很顺", "棋盘热了", "稳稳的"]},
	{"min": 2, "lines": ["手感来了", "漂亮！", "稳！", "好眼力", "丝滑~", "就是这样", "节奏对了", "唰唰的"]}
]

# In-round streak milestones: combo -> blossom bonus, paid once each round.
const MILESTONES = {3: 2, 5: 3, 8: 5, 12: 8}

const TIER_LINES_KEY = 1
const TIER_MIN_KEY = 0


static func tier_for(combo: int) -> Dictionary:
	for tier in TIERS:
		if combo >= int(tier[TIER_MIN_KEY]):
			return tier
	return {}


# Draw the next line for this combo's tier. The tier's pool is shuffled into
# a deck held on `game.cheer_decks` and consumed one by one — no repeats
# until the deck runs dry, then it reshuffles.
static func draw(game, combo: int) -> String:
	var tier = tier_for(combo)
	if tier.empty():
		return ""
	var tier_key = str(tier[TIER_MIN_KEY])
	if not game.cheer_decks.has(tier_key):
		game.cheer_decks[tier_key] = []
	var deck: Array = game.cheer_decks[tier_key]
	if deck.empty():
		var lines: Array = tier[TIER_LINES_KEY]
		deck = lines.duplicate()
		for i in range(deck.size() - 1, 0, -1):
			var j = int(randi() % (i + 1))
			var swap = deck[i]
			deck[i] = deck[j]
			deck[j] = swap
	var line = str(deck.pop_front())
	game.cheer_decks[tier_key] = deck
	return line


# One hook per matched pair: pick the praise line, pay any fresh milestone.
# Returns the burst text ("" when combo is too low to cheer).
static func on_combo(game, combo: int, gain: int) -> String:
	if combo < 2:
		return ""
	var line = draw(game, combo)
	for milestone in MILESTONES:
		if combo >= int(milestone) and not game.combo_milestones_hit.has(int(milestone)):
			game.combo_milestones_hit.append(int(milestone))
			var reward = int(MILESTONES[milestone])
			game._patch_progress_state({"coins_delta": reward})
			game._show_message("🌈 %d 连击达成 · 🌸+%d" % [int(milestone), reward], 1.6)
	if line == "":
		return ""
	return line + " +" + str(max(0, gain))
