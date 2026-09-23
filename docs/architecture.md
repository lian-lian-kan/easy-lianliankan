# 架构总览（2026-09-12）

## 模块布局

脚本按六域目录组织（board 棋盘 / modes 玩法 / session 会话与规则 / ui 主屏 / pages 页面外壳 / content 文案语音；game.gd 编排根与 audio_manager autoload 留根）。归属规则、依赖规则、规模门禁与增长剧本见 `docs/scaling.md`。

| 模块 | 职责 | 测试 |
|---|---|---|
| `scripts/game.gd` | 场景编排层：`_ready` 启动、状态常量与成员、薄壳委托（约 1434 行 / 290 函数，绝大多数为 1 行委托壳） | 13 个无头测试覆盖玩法行为 |
| `scripts/board/board_engine.gd` | 纯棋盘算法：路径 BFS、生成、重排、重力压实、迷雾环、计数与时间格式化 | `board_engine_test.gd` 全分支（含机制网格） |
| `scripts/board/board_mechanics.gd` | 机制状态域：五机制的消除伤害（冰甲两段/锁链解锁/叠层顶出）、重力压实触发、迷雾层数、可选性判定 | `panels_probe.gd`（机制行为断言）+ `frost/variants/mechanics_probe.gd` |
| `scripts/board/board_view.gd` | 棋盘视觉：全量刷新、格子样式/尺寸、图标映射、出生/洗牌动画 | `panels_probe.gd`（视觉断言） |
| `scripts/interactions/` | 交互域（多阶段交互状态机）：interaction_registry 登记交互类型（优先级/手势/武装维度/阶段表/每阶段提示），interaction_manager 是棋盘手势唯一入口（路由+阶段查询+草稿态重置+收回武装），power_target/pair_select/memory_pick/drag_link 四类交互各自承接「武装→瞄准→结算」「选牌→配对」「翻牌→配对」「按下→划入→松手」 | `interaction_manager_test.gd` + 既有输入探针 |
| `scripts/session/game_input.gd` | 输入域：棋盘手势委托交互模块（interactions/）的多阶段管理器；键盘路由、提示/自动消/洗牌/重开等对局动作，以及为既有调用方保留的委托薄壳 | `game_input_test.gd` + `panels_probe.gd` |
| `scripts/modes/special_session.gd` | 特殊模式会话：32 种玩法进出、结算纪录与发放、竞速判负、盲盒记忆、无尽轮间增益、boss 击败结算 | `flip_probe.gd` + `variants_probe.gd` |
| `scripts/session/session.gd` | 会话生命周期：关卡会话重置、走子后裁决（胜负/重排/重力）、暂停/恢复、判负；结算与计分委托 session_settle | `panels_probe.gd` + `session_settle_test.gd` |
| `scripts/session/session_settle.gd` | 结算与计分域（session 内容分册）：过关结算（时间奖励/星级/解锁推进）、连击计分、成就发放 | `session_settle_test.gd` + `session_combo_test.gd` |
| `scripts/session/game_config.gd` | 配置装载：JSON 覆盖 + 代码内默认回退（关卡表/调参/图标集/模式配置） | `panels_probe.gd`（重载断言） |
| `scripts/session/progress_store.gd` | 进度存取：加载/保存/补丁式更新（special 会话过滤战役字段） | `panels_probe.gd`（持久化断言） |
| `scripts/session/progression.gd` | 进度/成就/纪录的纯存档模型（apply_update/normalize/比较） | `progression_test.gd` |
| `scripts/modes/special_modes_data.gd` | 玩法数据：MODES 注册表（每玩法一行声明）+ 分类标题 + 战役标签 + 32 个模式默认配置（纯 const），全部展示/结算表面由注册表派生 | `special_modes_test.gd` + `mode_meta_test.gd` |
| `scripts/modes/special_modes.gd` | 特殊玩法配置/生成器/解锁/纪录键 + 注册表派生视图（record_modes/flat_best_keys/mode_categories/mode_label/intro_text/面板行） | `special_modes_test.gd` + `mode_meta_test.gd` |
| `scripts/modes/campaign_levels.gd` | 战役关卡数据表（深拷贝访问器） | `campaign_levels_test.gd`（数据不变量） |
| `scripts/session/powerups.gd` | 道具域：载荷规则（战役按关递进 + 特殊会话 SPECIAL_LOADOUT 三表）、取用流程（武装/收回/守卫）、点击目标执行 | `power_ups_probe.gd`（34 断言） |
| `scripts/ui/stats_hud.gd` | 统计 HUD：卡片构建/文本/道具槽显示/告警脉冲 + 标签工厂 | `stat_probe.gd` + `panels_probe.gd` |
| `scripts/modes/memory_flip.gd` | 翻翻乐：全暗牌翻配对状态机（翻错盖回）+ 卡面渲染 | `flip_probe.gd` |
| `scripts/modes/tile_match.gd` | 三消槽位玩法「叠叠消」：堆叠生成/遮挡判定/入槽三消状态机 + 牌堆与槽位渲染 | `tray_probe.gd` |
| `scripts/modes/drag_chain.gd` | 连线消纯链数学：相邻/延伸判定与链计分（手势推进在交互域 drag_link.gd） | `drag_probe.gd` |
| `scripts/pages/page_router.gd` | 页面路由壳：底部导航 + 页面容器/开关/重建 + 动线页（玩法大厅/任务，含「前往」闭环出口） | `page_probe.gd` |
| `scripts/pages/page_ui.gd` | 页面框架工具：公共页头（返回+标题）与滚动内容区 | `page_probe.gd` |
| `scripts/pages/page_records.gd` | 记录陈列页（page_router 内容分册）：旅程地图/图鉴/数据汇总/攀登树/成就 | `page_probe.gd` |
| `scripts/pages/page_events.gd` | 活动页（page_router 内容分册）：周末双倍/节日奖池/节日日历（events_calendar 供数） | `page_probe.gd` |
| `scripts/pages/economy.gd` | 樱花币经济：钱包 chip、每日签到、图集商店、收集进度统计 | `page_probe.gd` |
| `scripts/pages/start_screen.gd` | 首页（启动标题页）：进游戏先见首页再落棋盘，走 open_modal 暂停语义；`current_scene` 判据让 `-s` 探针自动走老路径（直达棋盘，既有探针零改动）；暂停面板「🌸 回到首页」随时可达 | `start_screen_probe.gd` |
| `scripts/ui/home_screen.gd` | 主屏构建：背景/页头/统计卡/道具行/控制区/棋盘区/钱包/页面与导航挂载 | `panels_probe.gd` |
| `scripts/ui/ui_hud.gd` | 主屏结构：构建/状态刷新/消息横幅/控制按钮/关卡选择胶水/连击条/成就通知 | `panels_probe.gd`（结构+行为断言） |
| `scripts/ui/hud_layout.gd` | 屏幕适配：视口分类（手机/竖屏/紧凑）与响应式布局（棋盘高度/边距/网格间距/统计卡与控件尺寸/竖屏头部压缩） | `panels_probe.gd`（布局断言） |
| `scripts/session/hud_timers.gd` | 会话心跳：计时器工厂与时钟/消息/错误/连击/高亮/推进/解冻/竞速回调 | `panels_probe.gd`（心跳行为断言） |
| `scripts/ui/ui_panels.gd` | 弹窗框架与强上下文面板：shell/挂载/开合生命周期（open/close_modal 暂停语义）、暂停面板、攀登树增益三选一 | `panels_probe.gd`（生命周期断言） |
| `scripts/ui/ui_preferences.gd` | 偏好面板族（ui_panels 内容分册）：新玩家引导、设置（音频行/功能入口/页面入口）、数据迁移、图集选项粘合 | `panels_probe.gd`（设置面板断言） |
| `scripts/ui/ui_fonts.gd` | 字体工厂与全局主题（快乐体→Noto→Emoji 兜底链，按字号缓存） | `panels_probe.gd`（缓存与挂载断言） |
| `scripts/ui/fx_layer.gd` | 特效发射：樱花飘落/撒花/消除粒子/连击爆字/过关庆典/补间工厂 | `power_ups_probe.gd`（层与撒花断言） |
| `scripts/audio_manager.gd` | 程序化音效与 BGM（autoload，裸全局名访问） | 手动验收 |
| `scripts/board/path_overlay.gd` | 连线绘制（Control） | `path_overlay_input_passthrough_test.gd` |
| `shell/mobile_shell.html` | H5 加载壳（粉色 + CSS 樱花 + DPR 钳制 2~3×） | `web_entry_status_mode_test.gd` |
| `tools/subset_fonts.py` | 字体子集化（快乐体→Noto→Emoji 兜底链） | 覆盖率断言内建 |

## 提取手法（后续拆分沿用）

1. 在 game.gd 中定位目标函数的**语义相邻**下一函数签名作为结束锚（先 grep 确认，禁止凭记忆）；span 终止必须认**全部顶层声明**（func/const/var），只认 func 会把函数之间夹着的文件级声明卷进迁移体。
2. 剪块搬入新模块；无场景依赖的做成 `extends Reference` 静态函数；需要游戏成员的以 `game` 参数显式传入（标识符加 `game.` 前缀，**上下文无关全量前缀**并对 game.gd 声明集做差集审计）。
3. game.gd 原地留**同名薄封装**，外部调用方零改动；向已有模块追加时用追加模式，禁止整文件重写。
4. 已踩实的坑：autoload（如 AudioManager）是**全局单例名**，静态函数里直接裸用，`game.AudioManager` 是运行时错误；**含 yield 的协程不能迁成静态函数**；GDScript 无命名实参，壳调用须位置传参；Dictionary `==`/`hash()` 是引用/顺序敏感比较，断言内容相等要逐键比；SceneTree 测试的 SCRIPT ERROR 不改退出码，必须配行为断言；**GDScript 3 的 bool==int 抛错且中断 quit 导致测试挂死**，断言助手按值类型取值；**ScrollContainer 的内建 HScrollBar/VScrollBar 是延迟加入的子节点**，`get_child(0)` 拿到的可能是滚动条而非内容盒——内容盒应在构建时注册到成员（如 game.modes_content），禁止 child-index 链遍历。
5. 每轮：worktree → 全量测试绿 → 导出 → 合并 main → CI 绿 → 线上 pck 验证（与干净检出导出比对 sha256，worktree 内未提交文件会污染本地导出）。

## 已知债务

- game.gd 约 1434 行编排层：`_ready` 启动胶水、成员声明与委托薄壳。函数级拆分已收敛（仅 4 个 >6 行协调胶水：flip/tray 输入分发、成就浮层关闭），进一步归并收益边际递减，按需处理。
- 玩法分发已表驱动化（CI 轮）：副标题由 `subtitle_record_key()` 从 MODES 注册表派生，道具装载查 `SPECIAL_LOADOUT` 三表，特殊会话判定走 `game._is_special_session()`。剩余 `special_mode == "xxx"` 比较均为模式特定行为分支（机制/结算/判负），属正常分发而非债务。
- **新增玩法清单**（2026-09-22 注册表化，mode_meta_test 完整性守卫自动拦截漏配）：
  ① `special_modes_data.DEFAULT_CONFIGS` 加配置行（mode_id/name/description/unlock_level 等）；
  ② `special_modes_data.MODES` 注册表加一行声明（icon/label/blurb/intro/cat/settle/sub 七字段）——标签、开局横幅、玩法面板行与分组、结算表（record_modes()）、副标题、统计页行、存档 schema（flat_best_keys()）全部由该行派生，一处声明处处生效；
  ③ 首胜成就文案进 achievements.gd（`<id>_first`）；④ 道具特供（可选）进 powerups.SPECIAL_LOADOUT_EXTRA；⑤ 可选：startup_probe 加启动 Witness。
  守卫强制：注册表与配置表互为镜像、行字段齐全且取值合法、分类存在且有成员、派生键命名规范、纪录成就已定义、存档 schema 30 键无孤儿。
- 未接线 manager（签到/商店等）已删除；如需启用从 git 历史恢复（b72e1c3 之前）。
- 双人联机与关卡编辑器需对战/编辑基建，另立项。
- `docs/code_review.md` 为审查主报告，P 项随整改滚动更新。
