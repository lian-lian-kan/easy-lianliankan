extends Reference

# Combo cheers: the little surprises that make every streak feel fresh.
# Praise lines are drawn from tiered pools through a shuffled deck, so the
# player keeps hearing new phrasing for dozens of matches before a repeat.
# Streak milestones pay a small blossom bonus once per round — an incentive
# spike to chase, not a farmable income.

# Tiered praise pools (combo >= key). 36 lines total; keep each line short
# enough for the burst label (<= 12 chars; latin letters count narrow).
const TIERS = [
	{"min": 10, "lines": ["Sophia 最棒！", "月亮为你打call", "星河都甜了", "完美小女神", "甜到冒泡啦", "forever 闪耀"]},
	{"min": 8, "lines": ["小仙女下凡", "Sophia 美到犯规", "樱色小风暴", "指尖的魔法", "花儿都开了", "梦幻连击", "甜甜的暴击"]},
	{"min": 6, "lines": ["五连小烟花", "闪闪发光呢", "全场最靓", "Sophia 小魔女", "粉红风暴", "太治愈啦", "软软的厉害"]},
	{"min": 4, "lines": ["连成小串串", "停不下来呀", "樱花开啦", "小宇宙发光", "甜品时间到", "Sophia 手速", "又甜又快", "小果冻手感"]},
	{"min": 2, "lines": ["哇，好厉害", "Sophia 小手真巧", "甜甜的开局", "温柔一刀", "指尖在发光", "就是这样呀", "节奏对了哟", "小可爱出手"]
}]

# In-round streak milestones: combo -> blossom bonus, paid once each round.
const MILESTONES = {3: 2, 5: 3, 8: 5, 12: 8}

# Clear-screen pet phrases: one is sprinkled over every victory screen.
const CLEAR_LINES = [
	"棋盘都被你甜化啦", "今天的你也很闪耀", "这里开满了小花",
	"为你撒了一把星星", "刚刚那波太赏心悦目", "又是被治愈的一天",
	"果实都为你熟透了", "风都是甜甜的", "你怎么这么可爱",
	"这局温温柔柔就赢了", "完美得像甜品店", "小花要给你鼓掌",
	" omg 太丝滑了吧", "又是心动的一局"
]

static func tier_for(combo: int) -> Dictionary:
	for tier in TIERS:
		if combo >= int(tier["min"]):
			return tier
	return {}


# Draw the next line for this combo's tier. The tier's pool is shuffled into
# a deck held on `game.cheer_decks` and consumed one by one — no repeats
# until the deck runs dry, then it reshuffles.
static func draw(game, combo: int) -> String:
	var tier = tier_for(combo)
	if tier.empty():
		return ""
	var tier_key = str(tier["min"])
	if not game.cheer_decks.has(tier_key):
		game.cheer_decks[tier_key] = []
	var deck: Array = game.cheer_decks[tier_key]
	if deck.empty():
		var lines: Array = tier["lines"]
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
			game.VOICE_LINES.play(game, "milestone")
			# 获得时刻三件套：奖励音 + 迸发特效。经 game 包装方法 has_method
			# 探测调用——测试假体没有这些方法时静默跳过。
			if game.has_method("_play_coin_sound"):
				game._play_coin_sound()
			if game.has_method("_spawn_reward_burst"):
				game._spawn_reward_burst()
	if line == "":
		return ""
	return line + " +" + str(max(0, gain))


# Husband rescue lines: warm, doting, a little show-offy. The rescue is a
# product gimmick — the husband is always ready when time runs out.
const HUSBAND_LINES = [
	"老公来了，别怕！", "这有一对，看那里~", "别急，老公帮你看着呢",
	"时间？老公给你要来了", "慢慢来，我陪着你", "老公的外挂已上线",
	"小仙女只需要负责美", "剩下的交给老公", "深呼吸，就是那对", "老公时刻在线"
]


static func husband_line(game) -> String:
	var pick = int(randi() % HUSBAND_LINES.size())
	return str(HUSBAND_LINES[pick])


# A random pet phrase for victory screens; clears are rare enough that a
# plain random pick feels fresh without a deck.
static func clear_cheer(game) -> String:
	var pick = int(randi() % CLEAR_LINES.size())
	return str(CLEAR_LINES[pick])

# Reward-moment praise pools (Round 40): one-line phrases composed into the
# settle / mission / record / achievement banners, drawn through per-key
# decks so the phrasing rotates instead of repeating one template. Every
# line passed the Sep-19 font baseline check (漂/拿/添/碾/雅/贯/壁/封/勋/杯
# 都不在子集里，写文案前必须对基线池对拍).
const EVENT_POOLS = {
	"settle": ["甜度超标", "丝滑通关", "温柔通关", "完美收场", "顺顺过关"],
	"full_clear": ["全部通关", "关卡全清", "终点也开满花", "你就是传奇", "满载而归"],
	"mission": ["小目标达成", "任务清单打勾", "又进一步啦", "顺手就完成了", "进展神速"],
	"record": ["新纪录诞生", "快过闪电", "历史最快的一局", "手速无解", "收获满满"],
	"achievement": ["成就点亮", "高光时刻", "值得纪念", "里程碑达成"],
}


# Draw the next praise line for this reward moment (deck per key, held on
# game.cheer_decks alongside the combo decks).
static func draw_line(game, key: String) -> String:
	if not EVENT_POOLS.has(key):
		return ""
	var deck_key = "line:" + key
	if not game.cheer_decks.has(deck_key):
		var fresh = EVENT_POOLS[key].duplicate()
		fresh.shuffle()
		game.cheer_decks[deck_key] = fresh
	var deck: Array = game.cheer_decks[deck_key]
	if deck.empty():
		deck = EVENT_POOLS[key].duplicate()
		deck.shuffle()
		game.cheer_decks[deck_key] = deck
	var line = str(deck.pop_front())
	game.cheer_decks[deck_key] = deck
	return line
