# 代码质量报告（2026-09-14 质量攻坚轮）

范围：godot/scripts（游戏端，~9900 行 GDScript）与 backend/app（服务端，~1200 行 Python）。

## 门禁现状

| 门禁 | 位置 | 标准 |
|---|---|---|
| 后端测试覆盖率 | backend.yml（pytest-cov） | **`--cov-fail-under=100`，当前 100%**（39 用例，真 PG16+Redis7） |
| 后端静态审计 | tools/backend_audit.py | 函数 ≤45 行、禁 print/裸 except/通配导入 |
| 游戏静态审计 | godot/tools/shell_audit.py | 薄壳一致性、connect 目标、孤儿壳、Godot4 语法泄漏 |
| 游戏无头测试 | deploy.yml | **33 项无头测试/探针**入 CI 清单（godot/tests 共 37 文件），全部逻辑域有专属直测 |
| 生产端到端 | prod-e2e-check.yml（手动） | 真 Chrome 开线上页，断言云同步 API 流量 |

## 测试覆盖矩阵（游戏端：模块 → 专属测试）

- board_engine → board_engine_test；**board_pathfinder（新抽取）→ board_pathfinder_test**
- progression → progression_test；**achievements（新抽取）→ achievements_test**
- special_modes(+data) → special_modes_test；campaign_levels → campaign_levels_test
- missions / tile_match / memory_flip / progress_store / server_sync / economy / game_config / session 连击与结算 / content(cheers+voice) → 各自专属单测（本轮新增 11 个测试文件）

## 本轮发现并修复的真问题

1. **sum10 提示漏传 match_mode**（find_any_hint→find_path）：不同数字组合永远无提示，与消除规则不一致。
2. **HTTPRequest.use_utf8 赋值**：Godot 3.6 无此属性，原生/无头路径同步首触即崩。
3. **HTTPRequest.get_status() 守卫**：同因非法，已在删除守卫后由 request() 自身忙态拒绝兜底。
4. **path_overlay 透传测试假绿**：断言文本随早期重构搬到了 home_screen.gd，且 quit(1) 被末尾 quit(0) 覆盖——测试自那以后从未真正执行过。
5. **死代码**：core/security 的 token SQL 三函数（与 users_repo 重复）、users_repo.find_user_by_token、多个未用导入。

## 结构改进

- **SQL 单一归处**：core/security 瘦身为 mint/hash 纯原语；guards 迁 app/dependencies.py（HTTP 关注点），core 回归框架无关。
- **高内聚抽取**：board_engine 547→377（+board_pathfinder 208）；progression 507→461（+achievements 87）。抽取一律保留薄壳，调用方零改动。
- **常量单一来源**：钱包增量上限收敛到 config（schema/service 共享）。
- **基础设施**：Dockerfile 改装全量 requirements（原漏 redis）；部署清单与 edge 链路文档化。

## 第二波增量（同日续）

- **分支覆盖**：backend 覆盖门禁升级 `--cov-branch`（行+分支双 100%）。
- **高内聚抽取**：session/powerups 297→254（+powerup_loadout 63，道具发放梯子表驱动化）。
- **低耦合重构**：9 个模块 38 处 `AudioManager.` 编译期 autoload 依赖全部改为经
  `game.audio` 访问——`-s` 无头模式下 autoload 标识符不可解析，是多个测试静默跳过的根因。
- **新测试文件**：game_config / session_combo（连击增益全语义）/ session_settle（战役结算
  公式）/ powerup_loadout / content_sanity。无头 CI 清单 16→33 项，且全部真实执行
  （新增 quit() 静态门禁防挂死）。
- **教训**：抽取/改写数据表时必须先读原表内容——powerup_loadout 首版凭印象填了
  extra/override 两张表，被 power_ups_probe 即时抓出（这正是探针存在的意义）。

- **ui_style 抽取**：ui_panels 650→598（共享玻璃/按钮/对话框样式助手独立 ui_style.gd，
  5 个模块经薄壳共用）+ ui_style_test（五态样式/递归对话框着色）。
- **session_clock_test**：时钟/步数消耗守卫（无时钟不 drain、归零一次性触发 time-up、
  moves 专属预算、耗尽判负）与老公救援（一轮一次/+15s/死盘先重排）。

- **revive 抽取**：session 576→529（+revive 77，老公救援/时钟步数消耗/付费复活守卫独立；
  session_fail_test 经薄壳全量复核 + revive_test 直测）。

- **game_input 去重 + 专属单测**：427→398——普通/记忆两套同构的选择切换合并为一个
  （is_memory 门控翻开记账）；消除核心抽取 `_execute_match_core`（duel/slide/defense
  钩子共用，special_mode 单值语义保证记忆会话下必然惰性）。game_input_test 62 项直测：
  点击门禁/选择切换/拒绝路径（普规/sum10/金光/路径不通/对决换手）/消除核心与三模式钩子/
  记忆四态（翻开·预览锁·不一致双翻·路径阻塞保持选中）/hint·auto·shuffle·reset·jump·pause/
  键盘路由（含 playing 门禁与未映射键忽略）。CI 清单 34→35 项。

- **powerups 去重 + 首个专属单测**：bomb/rainbow 两条点击执行尾部约 25 行逐字重复
  （清选择/扣步/路径特效/连击得分/破冰/破链/resolve）抽取为 `_destroy_pair`（炸弹独有
  的碎石用 shatter_rocks 参数门控，行为严格等价）；顺带删除两处未使用的 score_result
  死变量、提取 _find_kind_partner/_shatter_rocks_around。powerups_test 30 项直测：
  装载重置/使用门禁（库存·暂停·模式限制）/收回退款/七种激活/炸弹（无伴退回·双格清除·
  碎冰·碎石）/彩虹（选择·取消·异色消除）/暖宝宝（未结冰不消耗）。CI 清单 35→36 项，
  _execute_bomb 44→15 行（最逼近红线的 WARN 清偿）。

- **progression 存档键名表驱动化**：default_progress / _normalize_special_records /
  same_progress 三函数里逐字重复的 24 个 `{mode}_best_score` 键清单收敛为单一常量
  `FLAT_BEST_KEYS`——新增玩法模式从改 3 处变改 1 处。三函数 45/40/43 行全部清偿至
  ≤35 行（shell_audit WARN 19→15）；同_progress 改卫语句式比较，语义与原实现逐字段
  等价（刻意保持不比 level_best_times 的原行为）。progression_test 增加表驱动增长守卫
  （24 键声明数/默认存档齐全/单键变更可被 same_progress 察觉）。

- **Round 7 棘轮清偿三函数**：session `_reset_board_session` 42 行拆出
  `_init_mode_boards`（棋盘形态机制：rock/defuse/sum/stack/chain，模式互斥保证重排
  等价）与 `_reset_interaction_state`（武装/高亮/路径草稿态）；session `_apply_combo_gain`
  39 行拆出 `_refund_attack_time`（限时/狂热返时钟）与 `_register_combo_score`（总分/
  云存档候选/周任务记账）；special_session `_start_special_mode` 42 行把逐模式
  虚拟关卡分派抽为 `_build_special_level`（每 builder 签名不同，保持显式分支并注明
  未知模式回落 endless）。**special_session_test 8 项首个会话域直测**：解锁门拒绝/
  classic 启动交接/daily 种子路径/memory 层级与专属开场白/rock 障碍/未知模式回落/
  time_attack 分派产出。CI 清单 36→37 项，WARN 棘轮 15→12。

- **Round 8**：fx_layer `_play_eliminate_effects` 45→20——连击→颜色/粒子数的 16 行
  if/elif 档位链收敛为 `COMBO_TIERS` 常量表 + `_combo_visuals` 纯函数查表（fx_layer_test
  13 项直测：五档边界/次档归属/intensity 双向缩放/封顶），星星 Label+补间构建抽
  `_spawn_combo_star`；board_engine 抽 `_blank_grid`/`_filled_cells` 助手， bury_stack_layer
  36→27 与 build_chain_grid 共用样板（WARN 12→10），board_engine_test 补埋层值域断言。

- **Round 9 棘轮归零**：最后 10 条视图构建告警全部清偿——economy `build_shop` 41→10
  （氛围主题区块/图集区块拆 `_build_theme_section`/`_build_set_section`）；page_router
  `build_pages` 42→3（页面面板与底部导航拆 `_build_page_surface`/`_build_nav_bar`）；
  home_screen 头部身份列/进度条/四个浮层拆五个构建器；ui_panels 三面板共享的
  「玻璃面板+挂载+24px 边距+内容盒」样板抽 `_modal_content_shell`（设置/成就复用，
  玩法面板的滚动区另拆 `_modes_rows_area`）；stats_hud `add_card` 39→33 抽 `_card_style`。
  全部为逐行原样搬移，add_child 顺序不变，行为等价由 panels_probe/page_probe/startup_probe
  场景探针回归保证。**shell_audit 规模棘轮自 Round CJ 引入以来首次 0 WARN。**

- **Round 10 纯逻辑域补测收官**：hud_layout_test 12 项直测 `_viewport_flags` 屏幕适配
  判定（手机竖/横屏、平板、桌面、860/460 两个含等号边界、flags 完整性）；content_decks_test
  20 项直测 cheers/voice_lines 牌堆——cheers 五档 tier 归属与封顶、同档整圈无重复、
  耗尽重洗、on_combo 门槛/加成文本/里程碑一次支付（combo 12 跨 5/8/12 三里程碑逐笔核对）、
  语音池数据不变量（非空 res:// ogg）、未知键静默、耗尽重洗。CI 清单 38→40 项。

- **Round 11 工具/计时域补测**：hud_timers_test 直测心跳与计时器清单——specs 指向真实
  回调、_build_timers 构建/存储/默认节奏、二秒心跳四道门（暂停/冻结/无尽/零时限）、
  defuse 炸弹逐秒 tick、shift 倒数到零换脸、defense 逼近丢距离与归零判负、race AI
  间隔节奏与终局判负、六个通用超时回调（含 endless 轮次推进与 null 安全）；ui_fonts_test
  直测字体工厂——按 px 缓存复用、8px 下限钳制、全局主题五控件绑定。CI 清单 40→42 项。

- **Round 12 布局管线直测**：hud_layout_test 扩至 26 项——update_layout 主管线
  （null 早退/竖屏压缩/桌面恢复/竖-横-竖幂等往返）、_apply_board_height 三分支
  （竖屏容器主导/横屏比率/桌面比率）、margins（竖屏归零+薄垫、桌面 16+64 导航带）、
  separations（竖屏 3px 换宽、桌面 10px）、stat 卡三档尺寸与竖屏 value-only pill、
  compact/restore 全量可见性往返。

- **Round 17 云同步与元页面补测**：server_sync_test 补 6 项——连接 banner 仅在状态
  转换时各触发一次（持续连接不重发、miss 翻转一次并排程）、节流窗口过期后 push 真正
  上线并写 pending_stamp、未知 lane 静默忽略（前向兼容）、坏 JSON 的 201 注册走重试路径；
  startup_probe 增加签到/商店页空账号渲染断言（页面打开可见、布局非空、回主页关闭）。
  后端 README 限流矩阵与代码一致性核对完成（Round 15 门禁 + 本轮五处数值同步）。

## 已知边界（记录不阻塞）

- 集群 pod→Service 通路故障期间，config.yaml 临时经 NodePort 连 PG/Redis（回退条件见文件注释）。
- session.gd 复活/超时块与 AudioManager/活动节点强耦合，无头直测不可行——由 startup_probe/panels_probe 等场景探针覆盖。
