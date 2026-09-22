# 扩展性契约（5~10 倍规模承载方案，2026-09-12）

目标：功能与代码量扩充 5~10 倍时，代码质量不塌、新人（含新 agent 会话）可导航、门禁自动拦劣化。
本文件是增长约束的单一事实源；architecture.md 记录现状，本文记录规则与剧本。

## 目录归属规则（2026-09-19 起，scripts/ 七域）

| 目录 | 域 | 判定问题 | 现有模块 |
|---|---|---|---|
| `scripts/`（根） | 编排根与基础设施 | 场景根脚本 / autoload？ | game.gd、audio_manager.gd |
| `scripts/board/` | 棋盘 | 只服务棋盘矩阵本身（算法/机制/视图/连线）？ | board_engine、board_mechanics、board_view、path_overlay |
| `scripts/interactions/` | 交互 | 玩家手势到棋盘的一段多阶段交互（登记/路由/阶段推进）？ | interaction_registry（类型登记，纯数据）、interaction_manager（路由门面）、pair_select、memory_pick、power_target、drag_link |
| `scripts/modes/` | 玩法 | 一种玩法（或玩法族）的状态机与数据表？ | special_modes、special_modes_data、special_session、campaign_levels、tile_match、memory_flip、drag_chain（纯链数学） |
| `scripts/session/` | 会话与规则 | 一局游戏的进程规则（输入/道具/任务/存档/时钟）？ | session、game_input、powerups、missions、progression、progress_store、game_config、hud_timers |
| `scripts/ui/` | 主屏 UI | 主屏的构建/刷新/适配/特效？ | ui_hud、ui_panels、home_screen、stats_hud、hud_layout、ui_fonts、fx_layer |
| `scripts/pages/` | 多页面外壳 | 页面导航与页面内经济？ | page_router、page_ui、economy |
| `scripts/content/` | 文案与语音内容 | 纯数据内容池（照 cheers 扩展范式）？ | cheers、voice_lines |

**新模块流程**：回答判定问题选目录 → game.gd 加 preload 常量 + 薄壳域段 → tests 加探针 → shell_audit 六项。拿不准就放 modes/ 或 ui/，两可时选被调用多的一方。

**新增交互类型剧本（interactions/ 域，2026-09-19 起）**：① `interaction_registry.gd` 加登记行（id/label/priority/gestures/phases，按需配 armed 维度与 phase_prompts）；② 新 handler 文件实现 `wants_press` / `phase` / `on_press`（drag 类再加 down/entered/up 三函数；阶段从可观察状态推导，不加跨局成员）；③ `interaction_manager.gd` 的 HANDLERS 挂表；④ `interaction_manager_test.gd` 补路由与阶段断言。阶段提示文案只能复用既有字符（否则重跑 `tools/subset_fonts.py`）。

## 依赖规则

- 模块一律 `extends Reference` 静态函数，需要状态时显式收 `game` 参数。
- **模块间禁止互相 preload**：跨模块调用走 `game.ALIAS.fn()`（game.gd 是唯一 preload 中枢，防环且调用点可审计）。已有少数文件内 preload（session→special_session 等）是既定单向例外，不新增；另有一个域级例外：**session/game_input → interactions 单向委托**（game_input 与 session 各自 preload interaction_manager），interactions/ 是叶子域、禁止反向 preload 其他域；interactions/ 域内 handler 之间的复用（memory_pick/drag_link → pair_select）为同域内聚单向边。
- 新增成员变量必须挂 game.gd 对应域段注释下；模块不得持有跨局状态。

## 质量门禁（tools/shell_audit.py，CI 硬门禁）

1~5：薄壳完整性 / connect 目标 / 孤儿薄壳(警告) / 孤儿成员(警告) / G4 语法残留 / 跨模块调用可解析。
6 规模门禁：新函数 >45 行 ERROR、>35 警告；非 game.gd 文件 >800 行 ERROR、>650 警告。

**棘轮规则**：`FUNC_LEN_RATCHET` 登记了 19 个存量超标函数（2026-09-12 快照），只许变小不许变大；重构轮拆掉一个函数就**删除对应条目**（审计输出 `ok-shrunk` 提醒降档）。禁止往表里加新条目。

## 增长剧本

- **新玩法**：architecture.md「新增玩法清单」——MODES 注册表一行声明后，标签/横幅/面板/分组/结算/副标题/统计页/存档 schema 全部自动派生（2026-09-22 注册表化，原 6 处散表收敛为 1 行）；mode_meta_test 完整性守卫兜底。
- **新页面**：page_router 加 PAGE 常量与构建函数；页面内业务进 economy 或新 pages/ 模块。
- **新内容池**（文案/语音/彩蛋）：content/ 下照 cheers 范式（纯数据池 + 洗牌队列 + 单一钩子）。
- **tests/ 分域（2026-09-19 已做）**：58 个测试文件按域镜像子目录（board/interactions/modes/session/ui/pages/content + 根目录保留 shell 专用 web_entry_status_mode_test）；新增测试按所测模块落目录。deploy.yml 清单路径与 shell_audit 递归 glob 已同步。

## 已知未来硬瓶颈（诚实清单，到阈值再立项）

1. **game.gd 线性增长**：每个新功能 +2~4 薄壳 + 成员变量；超 1500 行时启动「域状态对象」方案（成员收进域 holder，模块经 holder 访问），那是一次全局机械迁移，须单独轮次。
2. **ui_panels 586 / economy 430 行**：页面继续增多时 ui_panels 按面板拆文件（域规则下天然允许）；pages/ 已示范按内容分族拆分（page_records / page_events，2026-09-19）。
3. **Godot 3.6 EOL**：5~10 倍投入前应先决策是否迁 Godot 4（迁移成本与 G4 语法门禁反向，属战略决策非本轮范围）。
4. **preload 中枢单点**：game.gd 的 27 个 preload 常量是全仓依赖表；破 60 个时考虑按域拆「依赖清单」文件（纯 const，无逻辑）。
