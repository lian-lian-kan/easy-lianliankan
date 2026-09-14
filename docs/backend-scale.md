# 后端扩容与榜单/防外挂定案（2026-09）

目标：支撑 1000~2000 同时在线；榜单展示各用户积分与排行；自动化/外挂提交不得污染榜单。

## 1. 负载模型

游戏是「单机 + 云同步」：客户端只在登录、过关/结算时发请求（无固定心跳）。按 2000 在线、
人均 30s 一次同步估算 ≈ **70 req/s**，每请求 2~4 条短 SQL ≈ **250 SQL/s**——单 PG 实例
的舒适区（数万 SQL/s）。真正的风险不在总吞吐，而在：

1. **热路径放大赛**：每个 API 调用都查一次 PG 验 token（`current_user`）。
2. **读多写少的榜单**：实时 `RANK() OVER` 窗口聚合在 2000 人刷榜时重复计算。
3. **写放大**：每次写请求都 `UPDATE users SET last_seen_at`。

## 2. 容量改造（本批次落地）

| 项 | 改造 | 效果 |
| --- | --- | --- |
| token 验证 | Redis 缓存 `token_hash → user_id`（TTL 300s，refresh/登出即失效，Redis 不可用降级直查 PG） | 每请求省 1 条 PG 查询，砍掉热路径大头 |
| last_seen | 60s 节流（Redis SET NX EX；降级退化为每次直写） | 写放大 -90% |
| 连接池 | PG_POOL_MAX 默认 8 → 16/副本 | 2 副本 32 连接 < PG 默认 100 上限 |
| 线程池 | sync psycopg2 层共享线程池 40 → 100（THREAD_CAPACITY） | 消除 200 并发下的排队放大（p95 2.3s → <60ms） |
| 限流分层 | 认证写端点改 双层：per-user 细限（防单账号脚本）+ per-IP 粗限 3000/min（≈50 活跃玩家/NAT 地址，防单 IP 洪水不误伤合租网络） | 榜单防刷 + NAT 玩家不被误伤 |
| 榜单读 | Redis TTL 缓存（总榜 30s / 周期榜 15s） | 刷榜压力不落 PG |

水平扩展公式：`副本数 = ceil(峰值 req/s ÷ 单副本实测 RPS × 1.5 安全系数)`；连接池总量
`副本数 × PG_POOL_MAX < max_connections`。压测数据见 §6。

## 3. 防外挂/自动化（威胁模型先行）

**客户端完全可逆向**（H5/JS），任何藏在前端的密钥或校验都不可信。所以防线全部在服务端，
且目标明确收敛为：**榜单不可被自动化污染**。单机进度的coins/state 本身信任客户端
（篡改只影响自己的存档，不进任何公共面）。

成绩唯一入口 = `PUT /api/v1/progress`（整包 blob）。服务端在存档前做**成绩提取 + 三道门**：

1. **提取**：`score_intake` 从新旧 blob diff 出上涨的成绩（26 个键：24 个
   `{mode_id}_best_score` 顶层 + `endless_best.score` + `daily_challenge.best_score`）。
   无游戏端协议改动，存量客户端自动开始产数。
2. **分数天花板**：每模式 `max_score`（MODE_LIMITS 表，物理不可达值），超限整包照存但
   **不入榜** + 记审计日志（不惩罚正常游玩，只隔离污染）。
3. **节奏门**：同一用户同模式两次入榜成绩间隔 < `min_run_ms`（该模式一局的物理最短时长）
   → 不入榜 + 审计日志。last 时间戳优先 Redis（TTL 1d），miss 落 PG 查 events。
4. **速率限制补全**：`PUT /records`、`PUT /missions`、`POST /achievements` 补上限
   （此前仅 progress/wallet/signin/register 有限流）。

全部被拒提交照常返回 200（不惊动脚本作者），只有审计日志可见——**静默隔离**优于对峙。
`/records` REST 端点保留并走同一 anticheat 路径（为未来客户端直报预留）。

## 4. 榜单

新表 `mode_score_events`（追加式成绩流，通过门槛才写入）：
`(id BIGSERIAL, user_id, mode_id, score, created_at TIMESTAMPTZ)`，
索引 `(mode_id, created_at, score DESC)`。它同时是周期榜数据源与防外挂审计/节奏门数据源。

```
GET /api/v1/leaderboard/{mode_id}?period=all|weekly|daily&limit≤100
→ {mode_id, period, total_players,
   top: [{rank, user_id, nickname, score, achieved_at}...],
   my_rank}
```

- `all`：`mode_records`（历史最高，intake 维护 max 合并）
- `weekly|daily`：events 时间窗内 `MAX(score) GROUP BY user_id`
- `my_rank`：`COUNT(DISTINCT user_id) WHERE score > 我方` （走索引，替代窗口函数）
- 缓存：整包 JSON 入 Redis；写成绩时只失效 all 榜（周期榜靠短 TTL 自然过期）

隐私边界：榜单只暴露 user_id + nickname（自愿注册昵称），不暴露设备/IP 等任何标识。

## 5. 审计

- 全部拦截/放行决策在应用日志输出结构化行（rid/user/mode/score/verdict），可 grep 回溯。
- `mode_score_events` 本身是行为流水，事后可做离群分析（本批次不含 ML，只留数据面）。

## 6. 压测结论（tools/loadtest.py，真实 uvicorn+PG16+Redis7，本机 docker VM）

压测负载 = 每虚拟用户循环 [progress push（成绩递增，穿过 intake+anticheat）→ pull →
榜单读]，同步频率取真实玩家（~30s/次）的 15 倍强度。

**100 虚拟用户 × 60s（≈2000 在线的 2 倍真实峰值强度）：**

```
progress_put  ok=1999 fail=0  rps=31.4  p50=19.2ms p95=51.8ms  p99=81.8ms
progress_get  ok=1999 fail=0  rps=31.4  p50= 5.6ms p95=21.9ms  p99=35.7ms
leaderboard   ok=1999 fail=0  rps=31.4  p50=15.2ms p95=34.1ms  p99=50.2ms
TOTAL         ok=5997 fail=0  rps=94.1  error_rate=0.00%
```

**200 虚拟用户 × 60s（4 倍强度）：** 143.6 req/s 总吞吐，错误率 1.51%
（全部为 IP 粗限桶的预期 429，非故障），p50 27~56ms。

**结论：** 单 uvicorn 进程在本机 docker VM 上即承载 94 req/s @ p99 < 82ms、零错误。
生产 2 副本跑在独立 K8S 节点，2000 在线（≈70 req/s）的容量富余 ≥ 8 倍；
瓶颈不在线程/连接/DB，按 §2 公式水平加副本即可线性扩展。若未来负载增长 10 倍，
先扩副本与 PG 连接上限，再考虑 uvicorn workers 与 PG 读写分离。

压测教训：限流三层（register per-IP / 认证端点 per-user+per-IP）是压测首先撞上的
墙——脚本被迫串行注册并退避，这是服务器在正确工作；压测实例用
`REGISTER_RATE_LIMIT=1000` 放宽注册桶，业务桶保持生产值。

## 6.5 数据库存储与查询性能（tools/db_bench.py 实证）

**规模**：5000 用户 / 2500 token / 25,000 mode_records / 195,000 score_events /
250,000 ledger 行（docker PG16，冷启动灌数后首轮 EXPLAIN ANALYZE）：

```
token_lookup         0.08 ms   leaderboard_top        0.18 ms
leaderboard_my_rank  0.12 ms   events_window_top      0.10 ms
events_last_score    0.14 ms   wallet_balance_sum     0.20 ms
wallet_entries       0.04 ms                    → 全部索引命中，无大表 Seq Scan
```

存储与查询治理项（2026-09-15 落地）：

| 项 | 决策 | 理由 |
| --- | --- | --- |
| 连接池 | SimpleConnectionPool → **ThreadedConnectionPool** | 100 线程并发 getconn/putconn，Simple 无锁有竞态——正确性修复 |
| 钱包余额 | `SUM()` 全流水聚合 → **Redis 缓存（TTL 300s，append 以事务内精确值回写）** | 账本只增不减，不缓存则每次读余额线性变慢 |
| events 存储 | 90 天保留，**进程启动时 prune**（幂等 DELETE，双副本并发安全） | 周期榜只回看 7 天；账本(ledger)是账目记录永不删 |
| 响应带宽 | GZipMiddleware（≥1KB 才压） | progress blob 多 KB JSON，移动端带宽压缩 5~10x |
| 索引 | 现状已够（ledger (user_id,entry_id DESC)、events (mode_id,created_at,score) 与 (user_id,mode_id,created_at)） | db_bench 每条热查询 EXPLAIN 实证 |

**防假绿**：db_bench 先校验数据量——残留测试数据（几十个用户）不足以代表目标规模，
不足即 TRUNCATE 重灌；guard 阈值 BIG_TABLE_ROWS=10000（auth_tokens 在 2500 行时
planner 选 Seq Scan 是正确决策，表涨到万行级自动切索引，不算失败）。

## 6.5 代码审查结论（Round 13，分层/事务/索引/校验）

整体结论：四层分层（routers→services→repositories→core）无 SQL 泄漏到服务层、
无循环内查询（无 N+1）、全部写路径参数化。审查发现并当场修复三项：

1. **score_intake 多模式写入无原子性**——一次 push 同时上涨多个模式成绩时，
   事件流与总榜写入各自独立提交，中途失败会留下半入账。已包单事务。
2. **seed_modes 无事务**——启动时 26 条 upsert 逐条提交，失败留半注册注册表。
   已包单事务。
3. **过期 token 永不清理**——refresh/登出会删行，但被遗弃账号的过期 token
   行永久滞留。已加入启动维护（幂等 DELETE）。

审查过并判定为「无需改动」的面（记录避免重复排查）：

- 索引：全部热查询已被覆盖（见 §6.5 db_bench 实证），无缺失索引。
- 校验：所有写端点都有 schema 硬边界（pydantic ge/le/max_length）+ 限流；
  成绩另过 anticheat 三道门。
- 事务：register / refresh / wallet_append 原已使用事务；本次补齐 intake
  与 seed_modes。
- N+1：服务层循环内无仓库调用（grep 审计）。
- 已知并接受：单 push 多模式上涨时 pace 门逐模式查询（真实 push 几乎都是
  单模式成绩，优化属过度设计）。

## 7. 部署清单

- migration 006（score_events）先于新镜像上线（runner 自带顺序保证）。
- 镜像 v3 滚动更新；ANTICHEAT 默认 enforce（env `ANTICHEAT_OFF=1` 可全局旁路，用于救火）。
- 上线后验证：线上报超天花板成绩 → 审计日志可见拦截、榜单无该记录。
