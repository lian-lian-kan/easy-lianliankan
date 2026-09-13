"""Mirror of the game's special-mode table (special_modes_data.gd).

seed_modes upserts so later game versions can extend the registry without a
migration; keep this list in sync when the game adds modes.
"""

MODES = [
    {"mode_id": "time_attack", "label": "限时挑战", "unlock_level": 5},
    {"mode_id": "endless", "label": "无尽模式", "unlock_level": 8},
    {"mode_id": "daily", "label": "每日挑战", "unlock_level": 1},
    {"mode_id": "memory", "label": "盲盒模式", "unlock_level": 10},
    {"mode_id": "frost", "label": "冰雪挑战", "unlock_level": 13},
    {"mode_id": "zen", "label": "休闲模式", "unlock_level": 1},
    {"mode_id": "hell", "label": "地狱模式", "unlock_level": 12},
    {"mode_id": "moves", "label": "步数挑战", "unlock_level": 14},
    {"mode_id": "race", "label": "竞速对战", "unlock_level": 15},
    {"mode_id": "stack", "label": "叠层模式", "unlock_level": 15},
    {"mode_id": "gravity", "label": "重力模式", "unlock_level": 15},
    {"mode_id": "fog", "label": "迷雾模式", "unlock_level": 15},
    {"mode_id": "chain", "label": "锁链模式", "unlock_level": 15},
    {"mode_id": "tray", "label": "叠叠消", "unlock_level": 13},
    {"mode_id": "collect", "label": "收集挑战", "unlock_level": 14},
    {"mode_id": "flip", "label": "翻翻乐", "unlock_level": 15},
    {"mode_id": "fever", "label": "狂热模式", "unlock_level": 15},
    {"mode_id": "perfect", "label": "完美模式", "unlock_level": 15},
    {"mode_id": "rock", "label": "障碍模式", "unlock_level": 14},
    {"mode_id": "defuse", "label": "拆弹行动", "unlock_level": 15},
    {"mode_id": "target", "label": "指定连消", "unlock_level": 14},
    {"mode_id": "shift", "label": "变脸模式", "unlock_level": 15},
    {"mode_id": "slide", "label": "滑移模式", "unlock_level": 16},
    {"mode_id": "defense", "label": "守卫模式", "unlock_level": 16},
    {"mode_id": "sum10", "label": "合十消", "unlock_level": 17},
    {"mode_id": "duel", "label": "同屏对战", "unlock_level": 17},
]
