# 连连看游戏设计优化文档

> 版本：v1.0
> 目标引擎：Godot 3.5 LTS
> 最后更新：2026-03-23

---

## 一、现有系统分析

### 1.1 关卡系统
当前15个关卡配置如下：

| 关卡ID | 名称 | 模式 | 棋盘大小 | 种类数 | 时间限制 | 问题分析 |
|--------|------|------|----------|--------|----------|----------|
| 1 | 热身 | classic | 8x6 | 6 | 90s | ✅ 合理 |
| 2 | 提速 | rush | 10x6 | 7 | 100s | ✅ 合理 |
| 3 | 连击 | combo | 10x7 | 8 | 110s | ✅ 合理 |
| 4 | 压迫 | rush | 12x7 | 8 | 120s | ✅ 合理 |
| 5 | 终局 | endurance | 12x8 | 9 | 130s | ✅ 合理 |
| 6 | 破阵 | combo | 10x10 | 10 | 136s | ✅ 合理 |
| 7 | 双线冲刺 | rush | 12x9 | 10 | 144s | ✅ 合理 |
| 8 | 迷城 | endurance | 14x8 | 11 | 152s | ✅ 合理 |
| 9 | 高压连段 | combo | 12x10 | 11 | 160s | ✅ 合理 |
| 10 | 王座 | endurance | 13x10 | 12 | 168s | ✅ 合理 |
| 11 | 极限挑战 | rush | 14x10 | 12 | 150s | ⚠️ 时间略紧 |
| 12 | 记忆大师 | classic | 12x12 | 14 | 180s | ✅ 合理 |
| 13 | 闪电战 | rush | 10x10 | 10 | 90s | ❌ 时间断崖式下降 |
| 14 | 连击风暴 | combo | 12x10 | 13 | 160s | ✅ 合理 |
| 15 | 终极试炼 | endurance | 14x12 | 15 | 200s | ✅ 合理 |

### 1.2 主题系统
当前14套主题皮肤，涵盖多种风格：
- 水果派对、汽车总动员、职业达人、美妆时尚
- 萌宠动物园、美食大赏、运动健将、自然风光
- 动漫世界、樱桃小丸子、海洋世界、太空探索
- 十二星座、天气预报

### 1.3 数值配置
```json
{
  "base_score": 10,
  "combo_window_ms": 2600,
  "max_combo": 8,
  "time_danger_seconds": 10
}
```

---

## 二、优化方案

### 2.1 关卡数值平衡

**问题识别：**
- 第13关"闪电战"时间从第12关的180s骤降到90s，难度曲线不合理
- 第11关时间相对棋盘大小偏紧

**优化后的关卡配置：**

```json
{
  "levels": [
    {"id": 1, "name": "热身", "mode": "classic", "rows": 8, "cols": 6, "kinds": 6, "time_limit": 90, "unlock_requirement": 0},
    {"id": 2, "name": "提速", "mode": "rush", "rows": 10, "cols": 6, "kinds": 7, "time_limit": 100, "unlock_requirement": 1},
    {"id": 3, "name": "连击", "mode": "combo", "rows": 10, "cols": 7, "kinds": 8, "time_limit": 110, "unlock_requirement": 2},
    {"id": 4, "name": "压迫", "mode": "rush", "rows": 12, "cols": 7, "kinds": 8, "time_limit": 120, "unlock_requirement": 3},
    {"id": 5, "name": "终局", "mode": "endurance", "rows": 12, "cols": 8, "kinds": 9, "time_limit": 130, "unlock_requirement": 4},
    {"id": 6, "name": "破阵", "mode": "combo", "rows": 10, "cols": 10, "kinds": 10, "time_limit": 136, "unlock_requirement": 5},
    {"id": 7, "name": "双线冲刺", "mode": "rush", "rows": 12, "cols": 9, "kinds": 10, "time_limit": 144, "unlock_requirement": 6},
    {"id": 8, "name": "迷城", "mode": "endurance", "rows": 14, "cols": 8, "kinds": 11, "time_limit": 152, "unlock_requirement": 7},
    {"id": 9, "name": "高压连段", "mode": "combo", "rows": 12, "cols": 10, "kinds": 11, "time_limit": 160, "unlock_requirement": 8},
    {"id": 10, "name": "王座", "mode": "endurance", "rows": 13, "cols": 10, "kinds": 12, "time_limit": 168, "unlock_requirement": 9},
    {"id": 11, "name": "极限挑战", "mode": "rush", "rows": 14, "cols": 10, "kinds": 12, "time_limit": 165, "unlock_requirement": 10},
    {"id": 12, "name": "记忆大师", "mode": "classic", "rows": 12, "cols": 12, "kinds": 14, "time_limit": 180, "unlock_requirement": 11},
    {"id": 13, "name": "闪电战", "mode": "rush", "rows": 10, "cols": 10, "kinds": 10, "time_limit": 120, "unlock_requirement": 12},
    {"id": 14, "name": "连击风暴", "mode": "combo", "rows": 12, "cols": 10, "kinds": 13, "time_limit": 160, "unlock_requirement": 13},
    {"id": 15, "name": "终极试炼", "mode": "endurance", "rows": 14, "cols": 12, "kinds": 15, "time_limit": 200, "unlock_requirement": 14}
  ]
}
```

**主要调整：**
- 第11关：150s → 165s（增加15秒）
- 第13关：90s → 120s（增加30秒，避免断崖）

---

### 2.2 新增游戏模式

#### 模式1：限时挑战（Time Attack）

**规则：**
- 初始时间：60秒
- 消除一对：+3秒
- 连击额外奖励：连击数 × 1秒
- 游戏结束：时间归零
- 目标：获得尽可能高的分数

**特殊机制：**
- 每消除10对，随机出现"时间宝箱"（+10秒）
- 连击5+时，进入"狂热模式"（得分×1.5）

**配置文件：**
```json
{
  "mode_id": "time_attack",
  "name": "限时挑战",
  "description": "与时间赛跑，消除得时间",
  "initial_time": 60,
  "time_bonus_per_match": 3,
  "combo_time_bonus": 1,
  "fever_mode_threshold": 5,
  "fever_multiplier": 1.5,
  "time_chest_interval": 10,
  "time_chest_bonus": 10
}
```

#### 模式2：无尽模式（Endless）

**规则：**
- 无时间限制
- 每关完成后自动进入下一关
- 每5关增加1个种类
- 每3关棋盘扩大1格
- 失败条件：无解且无法洗牌

**关卡递增表：**
| 阶段 | 关卡范围 | 种类数 | 棋盘大小 |
|------|----------|--------|----------|
| 入门 | 1-5 | 6-8 | 8x6 → 10x6 |
| 进阶 | 6-10 | 9-11 | 10x7 → 12x8 |
| 大师 | 11-20 | 12-14 | 12x10 → 14x10 |
| 传说 | 21+ | 15+ | 14x12 → 最大16x14 |

**配置文件：**
```json
{
  "mode_id": "endless",
  "name": "无尽模式",
  "description": "挑战极限，看你能走多远",
  "base_kinds": 6,
  "kinds_increment_every": 5,
  "board_expansion_every": 3,
  "max_rows": 16,
  "max_cols": 14,
  "max_kinds": 20
}
```

#### 模式3：盲盒模式（Memory）

**规则：**
- 游戏开始：所有方块显示5秒
- 5秒后：所有方块翻面（显示统一背面）
- 玩家需要凭记忆匹配
- 点击一个方块：短暂显示图案（1秒）
- 点击第二个：如果匹配则消除，不匹配则重新翻面

**难度递进：**
- 第1-3关：显示时间5秒，翻回时间1秒
- 第4-6关：显示时间4秒，翻回时间0.8秒
- 第7-9关：显示时间3秒，翻回时间0.6秒
- 第10关+：显示时间2秒，翻回时间0.5秒

**配置文件：**
```json
{
  "mode_id": "memory",
  "name": "盲盒模式",
  "description": "考验你的记忆力",
  "preview_seconds": 5,
  "face_up_duration": 1.0,
  "difficulty_tiers": [
    {"level_range": [1, 3], "preview": 5.0, "face_up": 1.0},
    {"level_range": [4, 6], "preview": 4.0, "face_up": 0.8},
    {"level_range": [7, 9], "preview": 3.0, "face_up": 0.6},
    {"level_range": [10, 999], "preview": 2.0, "face_up": 0.5}
  ]
}
```

---

### 2.3 道具系统扩展

当前道具（3种）：
1. ⏱️ 时间冻结
2. 🎯 自动匹配
3. 🔄 洗牌

**新增道具设计：**

```json
{
  "power_ups": [
    {
      "id": "time_freeze",
      "name": "时间冻结",
      "icon": "⏱️",
      "description": "暂停时间5秒",
      "duration": 5.0,
      "max_charges": 3,
      "shortcut": "1"
    },
    {
      "id": "auto_match",
      "name": "自动匹配",
      "icon": "🎯",
      "description": "自动找到并消除一对",
      "max_charges": 3,
      "shortcut": "2"
    },
    {
      "id": "reshuffle",
      "name": "洗牌",
      "icon": "🔄",
      "description": "重新排列所有方块",
      "max_charges": 3,
      "shortcut": "3"
    },
    {
      "id": "magnifier",
      "name": "放大镜",
      "icon": "🔍",
      "description": "高亮显示3个可消除对",
      "max_charges": 2,
      "cooldown": 30.0,
      "shortcut": "4"
    },
    {
      "id": "time_sand",
      "name": "时光沙漏",
      "icon": "⏰",
      "description": "时间+15秒",
      "max_charges": 1,
      "per_level_limit": 1,
      "shortcut": "5"
    },
    {
      "id": "bomb",
      "name": "炸弹",
      "icon": "💣",
      "description": "随机消除一对",
      "max_charges": 5,
      "shortcut": "6"
    },
    {
      "id": "rainbow_chain",
      "name": "彩虹链",
      "icon": "🌈",
      "description": "无视路径直接消除（连击10+自动触发）",
      "max_charges": 0,
      "auto_trigger_combo": 10,
      "shortcut": ""
    },
    {
      "id": "super_shuffle",
      "name": "超级洗牌",
      "icon": "🔀",
      "description": "保证有解的洗牌",
      "max_charges": 2,
      "per_level_limit": 2,
      "shortcut": "7"
    }
  ]
}
```

---

### 2.4 经济系统设计

#### 2.4.1 货币系统

**金币（Coin）**
- 主要用途：购买道具、解锁主题、补充体力
- 获取途径：通关奖励、每日签到、成就、广告

**钻石（Gem）**
- 主要用途：购买高级主题、复活、加速体力恢复
- 获取途径：充值、特殊成就、活动奖励

#### 2.4.2 金币获取规则

```json
{
  "coin_rewards": {
    "base_formula": "score * difficulty_multiplier * time_bonus_multiplier",
    "difficulty_multiplier": {
      "easy": 1.0,
      "normal": 1.2,
      "hard": 1.5,
      "expert": 2.0
    },
    "time_bonus_multiplier": {
      "above_50_percent": 1.5,
      "above_25_percent": 1.2,
      "below_25_percent": 1.0,
      "time_out": 0.5
    },
    "first_clear_bonus": 50,
    "perfect_clear_bonus": 100
  }
}
```

#### 2.4.3 每日签到奖励

```json
{
  "daily_rewards": [
    {"day": 1, "reward": {"type": "coin", "amount": 50}},
    {"day": 2, "reward": {"type": "coin", "amount": 100}},
    {"day": 3, "reward": {"type": "coin", "amount": 150}},
    {"day": 4, "reward": {"type": "coin", "amount": 200}},
    {"day": 5, "reward": {"type": "coin", "amount": 300}},
    {"day": 6, "reward": {"type": "coin", "amount": 400}},
    {"day": 7, "reward": {"type": "theme", "theme_id": "random_locked"}}
  ],
  "cycle_reset": true
}
```

#### 2.4.4 商店配置

```json
{
  "shop": {
    "items": [
      {
        "id": "theme_pack_basic",
        "name": "基础主题包",
        "type": "theme_bundle",
        "price": {"currency": "coin", "amount": 1000},
        "contents": ["fruit", "car", "animal"]
      },
      {
        "id": "theme_pack_premium",
        "name": "高级主题包",
        "type": "theme_bundle",
        "price": {"currency": "gem", "amount": 100},
        "contents": ["cosmetic", "anime", "maruko"]
      },
      {
        "id": "power_up_bundle",
        "name": "道具大礼包",
        "type": "power_up_bundle",
        "price": {"currency": "coin", "amount": 500},
        "contents": {
          "time_freeze": 3,
          "auto_match": 3,
          "reshuffle": 3,
          "magnifier": 2
        }
      },
      {
        "id": "energy_refill",
        "name": "体力补充",
        "type": "energy",
        "price": {"currency": "coin", "amount": 100},
        "amount": 1
      },
      {
        "id": "double_coin_card",
        "name": "双倍金币卡",
        "type": "booster",
        "price": {"currency": "coin", "amount": 200},
        "duration_minutes": 60,
        "effect": "coin_x2"
      }
    ]
  }
}
```

---

### 2.5 体力系统

**设计目的：** 控制游戏节奏，促进留存和社交

```json
{
  "energy_system": {
    "max_energy": 5,
    "recovery_time_minutes": 20,
    "cost_per_game": 1,
    "cost_on_failure": 0,
    "refill_methods": {
      "natural_recovery": true,
      "coin_purchase": {"cost": 100, "amount": 1},
      "gem_purchase": {"cost": 10, "amount": 5},
      "friend_gift": {"max_per_day": 3, "amount": 1},
      "ad_reward": {"max_per_day": 5, "amount": 1}
    },
    "max_overflow": 10
  }
}
```

---

### 2.6 社交系统

#### 2.6.1 排行榜

```json
{
  "leaderboards": [
    {
      "id": "total_score",
      "name": "总分榜",
      "type": "global",
      "reset_period": "weekly",
      "reward_top": 100
    },
    {
      "id": "level_speedrun",
      "name": "关卡速通榜",
      "type": "per_level",
      "reset_period": "never"
    },
    {
      "id": "endless_depth",
      "name": "无尽模式深度榜",
      "type": "global",
      "reset_period": "monthly"
    },
    {
      "id": "friends",
      "name": "好友榜",
      "type": "friends_only",
      "reset_period": "weekly"
    }
  ]
}
```

#### 2.6.2 分享与邀请

```json
{
  "social_features": {
    "share_reward": {"type": "coin", "amount": 50, "max_per_day": 3},
    "invite_reward": {
      "inviter": {"type": "gem", "amount": 10},
      "invitee": {"type": "coin", "amount": 500}
    },
    "friend_gift": {
      "send_limit": 5,
      "receive_limit": 3,
      "reward": {"type": "energy", "amount": 1}
    },
    "ask_for_help": {
      "cooldown_hours": 24,
      "reward": {"type": "hint", "amount": 1}
    }
  }
}
```

---

## 三、UI/UX优化建议

### 3.1 主界面重构

```
┌─────────────────────────────────────────┐
│  [Logo]              💰 1234   ❤️ 5/5   │
├─────────────────────────────────────────┤
│                                         │
│     ┌──────────┐    ┌──────────┐       │
│     │ 🎮       │    │ 📋       │       │
│     │ 继续游戏 │    │ 选择关卡 │       │
│     └──────────┘    └──────────┘       │
│                                         │
│     ┌──────────┐    ┌──────────┐       │
│     │ ⏱️       │    │ ♾️       │       │
│     │ 限时挑战 │    │ 无尽模式 │       │
│     └──────────┘    └──────────┘       │
│                                         │
│     ┌──────────┐    ┌──────────┐       │
│     │ 🎁       │    │ ⚙️       │       │
│     │ 每日奖励 │    │ 设置     │       │
│     └──────────┘    └──────────┘       │
│                                         │
├─────────────────────────────────────────┤
│  [主题: 水果派对 ▼]  [商店] [排行榜]    │
└─────────────────────────────────────────┘
```

### 3.2 游戏内特效升级

| 特效类型 | 当前实现 | 优化方案 |
|----------|----------|----------|
| 连击提示 | 文字显示 | 数字+火焰/闪电动画+震动效果 |
| 消除动画 | 简单缩放 | 粒子爆炸+音效同步 |
| 时间警告 | 红闪 | 边缘红光+心跳音效+数字跳动 |
| 路径显示 | 橙色线条 | 发光线条+粒子拖尾 |
| 胜利效果 | 简单文字 | 彩纸雨+音效+统计展示 |

---

## 四、开发优先级

### P0 - 核心体验（必须完成）
1. ✅ 关卡数值平衡调整
2. ⬜ 连击动画特效升级
3. ⬜ 新手引导优化
4. ⬜ Godot 3.x TODO修复

### P1 - 留存提升（重要）
1. ⬜ 体力系统实现
2. ⬜ 每日签到系统
3. ⬜ 排行榜功能
4. ⬜ 成就系统扩展

### P2 - 内容丰富（中等）
1. ⬜ 新游戏模式（限时挑战、无尽、盲盒）
2. ⬜ 商店系统
3. ⬜ 道具系统扩展
4. ⬜ 主题解锁机制

### P3 - 社交商业（可选）
1. ⬜ 好友系统
2. ⬜ 广告接入
3. ⬜ 内购项目
4. ⬜ 公会/战队

---

## 五、配置文件汇总

### 5.1 完整经济配置

详见：`godot/data/economy.json`

### 5.2 新模式配置

详见：`godot/data/game_modes.json`

### 5.3 扩展道具配置

详见：`godot/data/power_ups_extended.json`

---

**下一步行动：**
1. 等待技术团队评估实现难度
2. 优先实现P0级别的核心体验优化
3. 分阶段推进新功能开发
