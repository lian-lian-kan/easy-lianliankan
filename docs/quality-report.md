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

## 已知边界（记录不阻塞）

- 集群 pod→Service 通路故障期间，config.yaml 临时经 NodePort 连 PG/Redis（回退条件见文件注释）。
- session.gd 复活/超时块与 AudioManager/活动节点强耦合，无头直测不可行——由 startup_probe/panels_probe 等场景探针覆盖。
