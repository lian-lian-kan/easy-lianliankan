# 架构总览（2026-09-07）

## 模块布局

| 模块 | 职责 | 测试 |
|---|---|---|
| `scripts/game.gd` | 场景编排与游戏状态（约 3900 行，持续拆分中） | 10 个无头探针覆盖玩法行为 |
| `scripts/board_engine.gd` | 纯棋盘算法：路径 BFS、生成、重排、重力、迷雾环、时间格式化 | `board_engine_test.gd` 全分支 |
| `scripts/special_modes.gd` | 特殊玩法配置/生成器/解锁/纪录键 + 模式标签与开场文案 | `special_modes_test.gd` + `mode_meta_test.gd` |
| `scripts/progression.gd` | 进度/成就/纪录的存档模型（纯函数 apply_update） | `progression_test.gd` |
| `scripts/stats_hud.gd` | 统计 HUD：卡片构建、文本、道具槽显示、倒计时告警脉冲 | `stat_probe.gd` |
| `scripts/ui_panels.gd` | 五个弹窗面板的静态工厂（onboarding/settings/achievements/pause/modes） | `panels_probe.gd` |
| `scripts/fx_layer.gd` | 樱花飘落/撒花特效发射 | `mechanics_probe.gd`（层与撒花断言） |
| `scripts/audio_manager.gd` | 程序化音效与 BGM（autoload） | 手动验收 |
| `scripts/path_overlay.gd` | 连线绘制（Control） | `path_overlay_input_passthrough_test.gd` |
| `shell/mobile_shell.html` | H5 加载壳（粉色 + CSS 樱花） | `web_entry_status_mode_test.gd` |
| `tools/subset_fonts.py` | 字体子集化（快乐体→Noto→Emoji 兜底链） | 覆盖率断言内建 |

## 提取手法（后续拆分沿用）

1. 在 game.gd 中定位目标函数的**语义相邻**下一函数签名作为结束锚（先 grep 确认，禁止凭记忆）。
2. 剪块搬入新模块；无场景依赖的做成 `extends Reference` 静态函数；需要游戏成员的以 `game` 参数显式传入（标识符加 `game.` 前缀）。
3. game.gd 原地留**同名薄封装**，外部调用方零改动。
4. 用 `--check-only -s` 解析循环发现缺失的游戏成员并补白名单；注意静态函数中 autoload（如 AudioManager）也必须 `game.AudioManager`。
5. 每轮：worktree → 全量测试绿 → 导出 → 合并 main → CI 绿 → 线上 pck 验证。

## 已知债务

- game.gd 仍约 3900 行：玩法会话（special session）与道具/统计的进一步拆分需先做模式类架构设计。
- 未接线 manager（签到/商店等）已删除；如需启用从 git 历史恢复（b72e1c3 之前）。
- `docs/code_review.md` 为审查主报告，P 项随整改滚动更新。
