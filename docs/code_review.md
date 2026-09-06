# 代码质量审查报告（2026-09-07）

基线：commit `56275e3`。审查范围：`godot/scripts/` 全部 13 个脚本、`godot/tests/` 10 个测试套件、`godot/project.godot` 自动加载配置。

## 规模盘点

| 文件 | 行数 | 状态 |
|---|---|---|
| scripts/game.gd | 4764 / 209 函数 | 巨石文件：UI 构建 + 13 种玩法会话 + 道具 + 特效 + 机制 + 音效调用全部在一个类 |
| scripts/special_modes.gd | 385 | 纯逻辑、有测试 ✅ |
| scripts/progression.gd | 287 | 纯逻辑、有测试 ✅ |
| scripts/audio_manager.gd | 272 | autoload、已接线 ✅ |
| scripts/leaderboard_manager.gd | 208 | **未接线**（autoload 注册但无人调用） |
| scripts/daily_reward_manager.gd | 145 | **未接线**（路线图：接主题解锁） |
| scripts/coins_manager.gd | 131 | **未接线** |
| scripts/shop_manager.gd | 129 | **未接线** |
| scripts/theme_manager.gd | 123 | 已接线（主题选择 UI）✅ |
| scripts/energy_manager.gd | 121 | **未接线** |
| scripts/path_overlay.gd | 33 | 已接线 ✅ |
| scripts/test_game.gd | 5 | **死代码**（遗留 stub，无场景引用） |

## 问题清单

- **P1（本轮整改）game.gd 巨石文件**：209 个函数承担 6 种职责。整改路线：按"纯逻辑 → UI 构建 → 特效"三层逐轮抽取，每轮全量测试绿。
- **P2（本轮整改）game.gd 内的纯算法不可独立测试**：路径 BFS/棋盘生成/重排/重力与场景状态耦合在同一类里。→ 抽出 `scripts/board_engine.gd`（静态、零场景依赖），game.gd 留薄封装，测试 100% 覆盖每个公共函数与分支。
- **P3（本轮修复）`_create_board` 奇数尺寸越界**：rows×cols 为奇数时 ids 比 cells 少 1，原实现会数组越界崩溃。engine 版加了尾部空格守卫。
- **P4（已修，0c84fe2）开局首帧不刷新**机制视觉。
- **P5（已修，56275e3）统计卡数值撑爆布局**。
- **P6 待办：5 个未接线 manager** 以 autoload 注册，每次启动都实例化（启动时间+内存浪费）。建议：要么接线（签到×主题解锁是既定路线图），要么降级为按需 load。
- **P7 待办：test_game.gd 死代码**，确认无引用后删除。
- **P8 待办：game.gd 的 UI 面板构建函数（settings/achievements/modes/pause/onboarding 五块）可抽为独立模块**（Round B）。
- **P9 待办：特效子系统（樱花/撒花/棋盘粒子）可抽为 fx 组件**（Round C）。

## 测试覆盖策略

"100% 覆盖"的落地口径：**每个被提取的纯逻辑模块，其全部公共函数与关键分支都有断言**（board_engine_test.gd 覆盖 16 个函数的全部分支：路径直连/绕行/围死/异种/空格/越界、提示过滤、重排奇偶、生成奇偶、重力移动与否、环数、时间格式）；game.gd 场景行为由 10 个无头探针覆盖（玩法链路、道具、机制、布局稳定性）。任何重构合入前 11 个套件必须全绿。

## Godot 3.6 API 陷阱备忘（避免重蹈）

- Color 没有 `lerp`（用 `linear_interpolate`）；Control 没有 `to_local`（用 `get_global_transform().affine_inverse()`）；Control 裁剪属性是 `rect_clip_content`（`clip_contents` 是 G4）。
- FlowContainer 无 align 属性，SHRINK_CENTER 会塌缩到最窄子项。
- HBox 子项最小宽度随文本增长——固定尺寸需包一层普通 Control。
- GDScript 无 `_is_xxx` 声明时整文件 parse 失败，所有 SceneTree 测试会静默挂死（用 ps 找僵尸 Godot + 读测试日志定位）。
