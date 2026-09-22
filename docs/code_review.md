# 代码质量审查报告（2026-09-07 基线，P 项随整改滚动更新）

基线：commit `56275e3`。审查范围：`godot/scripts/` 全部 13 个脚本、`godot/tests/` 10 个测试套件、`godot/project.godot` 自动加载配置。

## 规模盘点（2026-09-19 刷新）

| 文件 | 行数 | 状态 |
|---|---|---|
| scripts/game.gd | 1434 / 编排根 | 巨石已拆尽：六域抽取后仅剩成员声明 + 1 行委托薄壳（board/session/ui/pages/modes/interactions + content 域） |
| scripts/ui/ui_panels.gd | 586 | 弹窗面板工厂（<650 警线内）✅ |
| scripts/board/board_view.gd | 433 | 棋盘视觉 ✅ |
| scripts/pages/page_router.gd | 333 | 路由壳 + 动线页（玩法大厅/任务）✅ |
| scripts/modes/special_session.gd | 324 | 特殊模式会话 ✅ |
| scripts/pages/page_records.gd | 316 | 记录陈列页（旅程/图鉴/数据/大树/成就，2026-09-19 自 page_router 拆出）✅ |
| scripts/session/game_input.gd | 210 | 键盘 + 对局动作（棋盘手势已归 interactions/）✅ |
| scripts/pages/page_events.gd | 125 | 活动页（2026-09-19 拆出）✅ |
| scripts/interactions/ | 5 文件 ~600 | 多阶段交互域（2026-09-19 成立）✅ |
| 其余 ~40 文件 | — | 全部 <650 行、函数 ≤35 行（shell_audit 零警告）✅ |

## 问题清单

- **P1（已清偿）game.gd 巨石文件**：4764 行 → 1434 行薄壳编排层；六域目录 + game.ALIAS 依赖中枢（见 architecture.md / scaling.md）。
- **P2（已清偿）纯算法不可独立测试**：board_engine / board_pathfinder / progression / achievements 等纯逻辑模块全部独立直测。
- **P3（已修）`_create_board` 奇数尺寸越界**：engine 版加尾部空格守卫。
- **P4（已修，0c84fe2）开局首帧不刷新**机制视觉。
- **P5（已修，56275e3）统计卡数值撑爆布局**。
- **P6（已清偿）5 个未接线 manager**：已删除（见 architecture.md 已知债务）。
- **P7（已清偿）test_game.gd 死代码**：已删除。
- **P8（已清偿）UI 面板构建函数**：抽为 ui_panels.gd（+ ui_style.gd 共享样式）。
- **P9（已清偿）特效子系统**：抽为 fx_layer.gd。
- **P10（2026-09-19 清偿）shell_audit 存量 WARN**：page_router 710→333（拆出 page_records/page_events），6 个 36~44 行函数全部拆至 ≤35 行，孤儿成员 push_http 删除；审计七项全过且零警告。

## 测试覆盖策略

"100% 覆盖"的落地口径：**每个被提取的纯逻辑模块，其全部公共函数与关键分支都有断言**（board_engine_test.gd 覆盖 16 个函数的全部分支：路径直连/绕行/围死/异种/空格/越界、提示过滤、重排奇偶、生成奇偶、重力移动与否、环数、时间格式）；game.gd 场景行为由 10 个无头探针覆盖（玩法链路、道具、机制、布局稳定性）。任何重构合入前 11 个套件必须全绿。

## Godot 3.6 API 陷阱备忘（避免重蹈）

- Color 没有 `lerp`（用 `linear_interpolate`）；Control 没有 `to_local`（用 `get_global_transform().affine_inverse()`）；Control 裁剪属性是 `rect_clip_content`（`clip_contents` 是 G4）。
- FlowContainer 无 align 属性，SHRINK_CENTER 会塌缩到最窄子项。
- HBox 子项最小宽度随文本增长——固定尺寸需包一层普通 Control。
- GDScript 无 `_is_xxx` 声明时整文件 parse 失败，所有 SceneTree 测试会静默挂死（用 ps 找僵尸 Godot + 读测试日志定位）。
