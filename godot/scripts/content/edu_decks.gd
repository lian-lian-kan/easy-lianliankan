extends Reference

# 知识配对 subject decks: every concept contributes exactly one prompt face
# and one answer face (汉字↔拼音 / 单词↔翻译 / 算式↔答案). Faces are flat
# strings indexed by tile value - 1, so a concept c owns faces 2c-1 and 2c —
# the same face-splitting shape sum10 uses, generalized to text decks.

const SUBJECT_ORDER = ["hanzi", "english", "math"]

const SUBJECT_NAMES = {
	"hanzi": "汉字↔拼音",
	"english": "单词↔翻译",
	"math": "算式↔答案",
}

# 30 concepts per subject; every deck must stay concept-even so a 10x6 board
# (30 pairs) deals each concept exactly once.
const DECKS = {
	"hanzi": {
		"name": "汉字↔拼音",
		"faces": [
			"山", "shān", "水", "shuǐ", "火", "huǒ", "木", "mù", "金", "jīn",
			"土", "tǔ", "日", "rì", "月", "yuè", "石", "shí", "田", "tián",
			"门", "mén", "王", "wáng", "牛", "niú", "马", "mǎ", "羊", "yáng",
			"心", "xīn", "手", "shǒu", "口", "kǒu", "耳", "ěr", "雨", "yǔ",
			"云", "yún", "花", "huā", "鸟", "niǎo", "鱼", "yú", "虫", "chóng",
			"竹", "zhú", "米", "mǐ", "豆", "dòu", "叶", "yè", "风", "fēng",
		],
	},
	"english": {
		"name": "单词↔翻译",
		"faces": [
			"apple", "苹果", "cat", "猫", "dog", "狗", "sun", "太阳", "moon", "月亮",
			"star", "星星", "book", "书", "pen", "笔", "tea", "茶", "egg", "鸡蛋",
			"fish", "鱼", "bird", "鸟", "tree", "树", "flower", "花", "milk", "牛奶",
			"water", "水", "rice", "米饭", "cake", "蛋糕", "bus", "公交车", "car", "汽车",
			"door", "门", "bed", "床", "ball", "球", "box", "盒子", "hat", "帽子",
			"shoe", "鞋子", "rain", "雨", "snow", "雪", "fire", "火", "wind", "风",
		],
	},
	"math": {
		"name": "算式↔答案",
		"faces": [
			"3+5", "8", "9-4", "5", "2×3", "6", "10-7", "3", "4+4", "8",
			"12-5", "7", "6+6", "12", "11-3", "8", "5+7", "12", "14-6", "8",
			"3×4", "12", "15-8", "7", "7+5", "12", "16-9", "7", "4×4", "16",
			"2×9", "18", "13-6", "7", "8+4", "12", "17-8", "9", "5×3", "15",
			"6+9", "15", "14-5", "9", "7×2", "14", "18-9", "9", "9+6", "15",
			"12-4", "8", "6×3", "18", "15-7", "8", "8×2", "16", "11-2", "9",
		],
	},
}

static func has_subject(subject) -> bool:
	return DECKS.has(str(subject))

# Deterministic daily rotation: every player sees the same subject on the
# same day (epoch-day index mod subject count, hour pinned away from DST edges).
static func subject_for_date(date) -> String:
	var stamp = {
		"year": int(date.year), "month": int(date.month), "day": int(date.day),
		"weekday": 0, "hour": 12, "minute": 0, "second": 0
	}
	var day_index = int(int(OS.get_unix_time_from_datetime(stamp)) / 86400)
	return SUBJECT_ORDER[day_index % SUBJECT_ORDER.size()]

static func faces_for(subject) -> Array:
	var deck: Dictionary = DECKS.get(str(subject), DECKS["hanzi"])
	return deck["faces"]

# Tile face text for a board value; unknown values fall back to the number.
static func face_text(faces: Array, value: int) -> String:
	var index = int(value) - 1
	if index >= 0 and index < faces.size():
		return str(faces[index])
	return str(value)

# Edu rule: a prompt face (odd value) matches its answer face (even value) of
# the same concept; identical faces never match.
static func values_match(a: int, b: int) -> bool:
	if a == b or a <= 0 or b <= 0:
		return false
	return int((a - 1) / 2) == int((b - 1) / 2)
