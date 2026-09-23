extends Reference

# Achievement catalog and accessors over the progression state. Extracted
# from progression.gd (pure functions, no I/O); progression keeps delegating
# shells so historical call sites stay stable.

# Achievement definitions
# Achievement definitions
const ACHIEVEMENTS = [
	{"id": "first_clear", "name": "初次通关", "desc": "完成第1关"},
	{"id": "combo_novice", "name": "连击新手", "desc": "达成3连击"},
	{"id": "combo_master", "name": "连击大师", "desc": "达成10连击"},
	{"id": "speed_star", "name": "速度之星", "desc": "在30秒内完成一关"},
	{"id": "perfect_clear", "name": "完美通关", "desc": "不使用提示和自动消除完成一关"},
	{"id": "completionist", "name": "通关达人", "desc": "完成所有关卡"},
	{"id": "tray_first", "name": "叠叠消初胜", "desc": "首次完成叠叠消"},
	{"id": "collect_first", "name": "收集达人", "desc": "首次完成收集挑战"},
	{"id": "flip_first", "name": "记忆大师", "desc": "首次完成翻翻乐"},
	{"id": "fever_first", "name": "燃烧吧小宇宙", "desc": "完成一局狂热模式"},
	{"id": "perfect_first", "name": "零失误女神", "desc": "完成一局完美模式"},
	{"id": "memory_first", "name": "盲盒初体验", "desc": "完成一局盲盒模式"},
	{"id": "daily_streak_7", "name": "七日之约", "desc": "每日挑战连胜达到7天"},
	{"id": "endless_round_5", "name": "无尽探索者", "desc": "无尽模式达到第5轮"},
	{"id": "time_attack_1000", "name": "限时高手", "desc": "限时挑战得分达到1000"},
	{"id": "frost_first", "name": "冰雪初融", "desc": "完成一局冰雪挑战"},
	{"id": "frost_no_power", "name": "寒冰骑士", "desc": "不使用暖宝宝完成一局冰雪挑战"},
	{"id": "zen_first", "name": "闲云野鹤", "desc": "完成一局休闲模式"},
	{"id": "hell_first", "name": "地狱行者", "desc": "通关一次地狱模式"},
	{"id": "moves_first", "name": "精打细算", "desc": "完成一局步数挑战"},
	{"id": "moves_saver", "name": "节步大师", "desc": "步数挑战中保留20%以上步数通关"},
	{"id": "race_first", "name": "初胜机器人", "desc": "竞速对战中击败机器人"},
	{"id": "stack_first", "name": "叠层达人", "desc": "完成一局叠层模式"},
	{"id": "gravity_first", "name": "引力达人", "desc": "完成一局重力模式"},
	{"id": "fog_first", "name": "拨云见日", "desc": "完成一局迷雾模式"},
	{"id": "chain_first", "name": "斩断锁链", "desc": "完成一局锁链模式"},
	{"id": "rock_first", "name": "搬山道人", "desc": "完成一局障碍模式"},
	{"id": "defuse_first", "name": "拆弹专家", "desc": "完成一局拆弹行动"},
	{"id": "target_first", "name": "指哪打哪", "desc": "完成一局指定连消"},
	{"id": "shift_first", "name": "善变女神", "desc": "完成一局变脸模式"},
	{"id": "slide_first", "name": "滑移行者", "desc": "完成一局滑移模式"},
	{"id": "defense_first", "name": "守卫骑士", "desc": "完成一局守卫模式"},
	{"id": "sum10_first", "name": "合十高手", "desc": "完成一局合十消"},
	{"id": "diff1_first", "name": "差一高手", "desc": "完成一局差一消"},
	{"id": "mult_first", "name": "倍数高手", "desc": "完成一局倍数消"},
	{"id": "boss_first", "name": "Boss高手", "desc": "完成一局Boss挑战"},
	{"id": "duel_first", "name": "同屏赢家", "desc": "完成一局同屏对战"},
	{"id": "drag_first", "name": "一笔连消", "desc": "完成一局连线消"},
	{"id": "edu_first", "name": "知识学士", "desc": "完成一局知识配对"}
]




static func has_achievement(state, achievement_id: String) :
	var achievements = state.get("achievements", [])
	if typeof(achievements) != TYPE_ARRAY:
		return false
	return achievement_id in achievements


static func unlock_achievement(state: Dictionary, achievement_id: String) :
	if has_achievement(state, achievement_id):
		return state
	var achievements = state.get("achievements", [])
	if typeof(achievements) != TYPE_ARRAY:
		achievements = []
	achievements.append(achievement_id)
	state["achievements"] = achievements
	return state


static func get_achievement_info(achievement_id: String) :
	for achievement in ACHIEVEMENTS:
		if achievement["id"] == achievement_id:
			return achievement
	return {"id": "", "name": "", "desc": ""}


static func get_unlocked_achievements(state) :
	var achievements = state.get("achievements", [])
	if typeof(achievements) != TYPE_ARRAY:
		return []
	return achievements.duplicate()


static func get_all_achievements() :
	return ACHIEVEMENTS.duplicate()


static func get_achievement_definitions() :
	return ACHIEVEMENTS.duplicate()

