# 架构总览（2026-09-08）

## 模块布局

| 模块 | 职责 | 测试 |
|---|---|---|
| `scripts/game.gd` | 场景编排层：`_ready` 启动、状态常量与成员、薄壳委托（约 1650 行） | 13 个无头测试覆盖玩法行为 |
| `scripts/board_engine.gd` | 纯棋盘算法：路径 BFS、生成、重排、重力压实、迷雾环、计数与时间格式化 | `board_engine_test.gd` 全分支（含机制网格） |
| `scripts/board_view.gd` | 棋盘视觉：全量刷新、格子样式/尺寸、图标映射、出生/洗牌动画 | `panels_probe.gd`（视觉断言） |
| `scripts/game_input.gd` | 输入：棋盘点击（选中/配对/待发道具路由）、盲盒翻牌、键盘路由、提示/自动消 | `panels_probe.gd`（输入行为断言） |
| `scripts/session.gd` | 会话生命周期：关卡会话重置、走子后裁决（胜负/重排/重力）、特殊模式进出、结算与判负 | `panels_probe.gd`（会话行为断言） |
| `scripts/game_config.gd` | 配置装载：JSON 覆盖 + 代码内默认回退（关卡表/调参/图标集/模式配置） | `panels_probe.gd`（重载断言） |
| `scripts/progress_store.gd` | 进度存取：加载/保存/补丁式更新（special 会话过滤战役字段） | `panels_probe.gd`（持久化断言） |
| `scripts/progression.gd` | 进度/成就/纪录的纯存档模型（apply_update/normalize/比较） | `progression_test.gd` |
| `scripts/special_modes.gd` | 特殊玩法配置/生成器/解锁/纪录键 + 模式标签/开场文案/面板行数据 | `special_modes_test.gd` + `mode_meta_test.gd` |
| `scripts/campaign_levels.gd` | 战役关卡数据表（深拷贝访问器） | `campaign_levels_test.gd`（数据不变量） |
| `scripts/powerups.gd` | 道具域：载荷规则、取用流程（武装/收回/守卫）、点击目标执行 | `power_ups_probe.gd`（34 断言） |
| `scripts/stats_hud.gd` | 统计 HUD：卡片构建/文本/道具槽显示/告警脉冲 + 标签工厂 | `stat_probe.gd` + `panels_probe.gd` |
| `scripts/ui_hud.gd` | 主屏基础设施：构建/状态刷新/布局适配/计时器簇/消息横幅/控制按钮/成就通知 | `panels_probe.gd`（结构+行为断言） |
| `scripts/ui_panels.gd` | 五个弹窗面板静态工厂 + 共享样式（玻璃/按钮/对话框递归） | `panels_probe.gd` |
| `scripts/fx_layer.gd` | 特效发射：樱花飘落/撒花/消除粒子/连击爆字 | `power_ups_probe.gd`（层与撒花断言） |
| `scripts/audio_manager.gd` | 程序化音效与 BGM（autoload，裸全局名访问） | 手动验收 |
| `scripts/path_overlay.gd` | 连线绘制（Control） | `path_overlay_input_passthrough_test.gd` |
| `shell/mobile_shell.html` | H5 加载壳（粉色 + CSS 樱花 + DPR 钳制 2~3×） | `web_entry_status_mode_test.gd` |
| `tools/subset_fonts.py` | 字体子集化（快乐体→Noto→Emoji 兜底链） | 覆盖率断言内建 |

## 提取手法（后续拆分沿用）

1. 在 game.gd 中定位目标函数的**语义相邻**下一函数签名作为结束锚（先 grep 确认，禁止凭记忆）；span 终止必须认**全部顶层声明**（func/const/var），只认 func 会把函数之间夹着的文件级声明卷进迁移体。
2. 剪块搬入新模块；无场景依赖的做成 `extends Reference` 静态函数；需要游戏成员的以 `game` 参数显式传入（标识符加 `game.` 前缀，**上下文无关全量前缀**并对 game.gd 声明集做差集审计）。
3. game.gd 原地留**同名薄封装**，外部调用方零改动；向已有模块追加时用追加模式，禁止整文件重写。
4. 已踩实的坑：autoload（如 AudioManager）是**全局单例名**，静态函数里直接裸用，`game.AudioManager` 是运行时错误；**含 yield 的协程不能迁成静态函数**；GDScript 无命名实参，壳调用须位置传参；Dictionary `==`/`hash()` 是引用/顺序敏感比较，断言内容相等要逐键比；SceneTree 测试的 SCRIPT ERROR 不改退出码，必须配行为断言。
5. 每轮：worktree → 全量测试绿 → 导出 → 合并 main → CI 绿 → 线上 pck 验证（与干净检出导出比对 sha256，worktree 内未提交文件会污染本地导出）。

## 已知债务

- game.gd 约 1650 行编排层：`_ready` 启动流程、棋盘点击回调胶水、计时器回调与散点小函数；进一步归并收益边际递减，按需处理。
- 未接线 manager（签到/商店等）已删除；如需启用从 git 历史恢复（b72e1c3 之前）。
- 双人联机与关卡编辑器需对战/编辑基建，另立项。
- `docs/code_review.md` 为审查主报告，P 项随整改滚动更新。
