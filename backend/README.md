# Sophia's lianliankan — Backend (Python + PostgreSQL)

服务端存档与用户/玩法数据。分层架构：`routers`（HTTP）→ `services`（业务规则）→
`core`（连接池/迁移/token 安全）；`db/migrations/` 按域拆分的 SQL 迁移，启动时按版本号自动应用。

## 模块地图

```
app/
  main.py            # 应用装配：路由注册 / 全局异常封装 / 请求日志(X-Request-Id) / healthz 探库
  core/              # config（环境变量）/ db（连接池+事务）/ security（token 原语）
                     # guards（认证/限流依赖）/ migrations / ratelimit（滑动窗口）/ mode_seed
  models/schemas.py  # pydantic 请求/响应模型（硬边界：时间戳/数值/日期格式）
  routers/           # users / auth / progress / records(+leaderboard) / engagement（薄 HTTP 层）
  services/          # 业务规则（合并语义、校验、事务边界）——纯 Python 可单测
  repositories/      # 全部 SQL（users/progress/records/engagement/leaderboard）
db/migrations/       # 001 账号+令牌 / 002 进度快照 / 003 玩法+纪录 / 004 钱包+签到 / 005 成就+周任务
tools/backend_audit.py  # 静态质量门禁（函数 ≤45 行、print/裸 except/通配导入禁用）
tests/               # pytest（CI 带 pg service 真库跑）
```

分层规则：routers 不写业务、services 不写 SQL、repositories 不做决策——新端点照此三层加。

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

## 健壮性设计

- **事务**：`db.transaction()` 上下文（thread-local 连接）——注册/令牌轮换/钱包余额读回等多写操作原子化。
- **限流**：公共端点滑动窗口（注册 10/分、进度 PUT 60/分、钱包 30/分、签到 10/分，按 IP）。**Redis ZSET 共享窗口为主存储**（多副本全局限流天然生效），Redis 不可用自动降级进程内存窗口；窗口行为可离线单测。
- **入参硬边界**：pydantic 模型层拦（时间戳上限 2100 年、日期格式、数值范围）；服务层再拦未来时间戳（>5 分钟偏移直接 400，防写死后续存档）。
- **错误封装**：统一 `{"error": {"code", "detail"}}` 信封，未捕获异常 500 不泄栈；每个响应带 `X-Request-Id`（可透传上游），结构化请求日志（rid/method/path/status/耗时 ms）。
- **健康检查**：`/healthz` 真探数据库（SELECT 1），挂库返回 503 供负载均衡摘除。
- **质量门禁**：`tools/backend_audit.py` 在 CI 硬卡（函数长度红线 45 行与游戏侧一致；禁 print/裸 except/通配导入）。

## 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `DATABASE_URL` | 集群内 `postgres.database.svc.cluster.local:5432/lianlian` | PG 连接串（主机名，勿用 IP） |
| `REDIS_URL` | 集群内 `redis.database.svc.cluster.local:6379/0` | Redis 连接串 |
| `REDIS_ENABLED` | `1` | 关掉则限流降级为进程内存窗口 |
| `MAX_STATE_BYTES` | `262144` | 单份存档体积上限 |
| `PG_POOL_MIN` / `PG_POOL_MAX` | 1 / 8 | 连接池 |
| `TOKEN_TTL_DAYS` | `90` | 令牌有效期 |

默认值即 K8S 集群内主机名（`database` namespace，来源：local-server-001:~/k8s-service.txt）；
集群外跑本地开发时用 env 覆盖为 `local-server-002:30432` / `local-server-002:30379`。
`/healthz` 返回 `{"ok":true,"db":true,"redis":bool}`——PG 挂返回 503，Redis 挂仅降级限流不影响可用性。
