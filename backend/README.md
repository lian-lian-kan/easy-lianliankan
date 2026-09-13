# Sophia's lianliankan — Backend (Python + PostgreSQL)

服务端存档与用户/玩法数据。分层架构：`routers`（HTTP）→ `services`（业务规则）→
`core`（连接池/迁移/token 安全）；`db/migrations/` 按域拆分的 SQL 迁移，启动时按版本号自动应用。

## 模块地图

```
app/
  main.py            # 应用装配 + 路由注册 + 26 玩法注册表 seed
  core/              # config（环境变量）/ db（连接池+查询助手）/ security（token）/ migrations
  models/schemas.py  # pydantic 请求/响应模型
  routers/           # users / auth / progress / records(+leaderboard) / engagement
  services/          # user / progress / records / engagement / leaderboard
db/migrations/       # 001 账号+令牌 / 002 进度快照 / 003 玩法+纪录 / 004 钱包+签到 / 005 成就+周任务
tests/               # pytest（CI 带 pg service 真库跑）
```

## 数据表

| 表 | 作用 |
|---|---|
| `users` | 账号（UUID、昵称、创建/最近活跃） |
| `auth_tokens` | 登录令牌（只存 SHA-256，90 天过期，可刷新轮换） |
| `progress_snapshots` | 每用户 progression_state 整包（JSONB + updated_at 陈旧写拒绝） |
| `modes` | 玩法注册表（26 种特殊玩法，启动 seed，随游戏版本扩展） |
| `mode_records` | 每用户×每玩法：最佳分（max 合并）/次数/胜场，排行榜数据源 |
| `achievements` | 每用户成就（幂等解锁） |
| `missions_progress` | 每用户×周任务（week_key 滚动周，进度 max 合并 + 领取位） |
| `economy_ledger` | 樱花币流水（追加式，余额=SUM(delta)） |
| `signin_log` | 每日签到（每人每日一行，幂等） |

## API（Bearer token 认证）

| Method | Path | 说明 |
|---|---|---|
| GET | `/healthz` | 存活检查 |
| POST | `/api/v1/users/register` | 注册（可选昵称）→ `{user_id, token}` |
| GET | `/api/v1/users/me` | 个人资料 |
| POST | `/api/v1/users/rename` | 改昵称 |
| POST | `/api/v1/auth/refresh` | 令牌轮换（旧令牌立即失效） |
| GET/PUT | `/api/v1/progress` | 云端存档（PUT 带客户端 unix-ms 时间戳） |
| GET | `/api/v1/modes` | 玩法注册表 |
| GET | `/api/v1/records` | 自己的全部玩法纪录 |
| PUT | `/api/v1/records/{mode_id}` | 上报一局结果（best_score=max、plays/wins 累加） |
| GET | `/api/v1/leaderboard/{mode_id}` | 排行榜 + 自己名次 |
| GET/POST | `/api/v1/achievements[/{id}]` | 成就查询/解锁（幂等） |
| GET/PUT | `/api/v1/missions` | 周任务查询/上报 |
| GET/POST | `/api/v1/wallet[/entries]` | 钱包余额 + 流水 |
| GET/POST | `/api/v1/signin` | 签到（幂等）/ 签到记录 |

## 本地起服务 / 测试

```bash
cd backend
docker compose up --build            # api :8000 + postgres
export DATABASE_URL=postgresql://lianlian:lianlian@localhost:5432/lianlian
pip install -r requirements.txt
python -m pytest tests -q            # SKIP_PG_TESTS=1 跳过 DB 用例
```

## 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `DATABASE_URL` | `postgresql://lianlian:lianlian@localhost:5432/lianlian` | PG 连接串 |
| `MAX_STATE_BYTES` | `262144` | 单份存档体积上限 |
| `PG_POOL_MIN` / `PG_POOL_MAX` | 1 / 8 | 连接池 |
| `TOKEN_TTL_DAYS` | `90` | 令牌有效期 |
