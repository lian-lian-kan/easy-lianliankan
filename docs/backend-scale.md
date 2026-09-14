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

## 6. 压测结论（tools/loadtest.py，真实 uvicorn+PG+Redis）

（待批次D回填：RPS / p50 / p99 / 错误率 / PG 连接占用 → 2000 在线结论）

## 7. 部署清单

- migration 006（score_events）先于新镜像上线（runner 自带顺序保证）。
- 镜像 v3 滚动更新；ANTICHEAT 默认 enforce（env `ANTICHEAT_OFF=1` 可全局旁路，用于救火）。
- 上线后验证：线上报超天花板成绩 → 审计日志可见拦截、榜单无该记录。
