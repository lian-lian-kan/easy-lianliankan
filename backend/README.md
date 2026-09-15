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
| `modes` | 玩法注册表（27 种特殊玩法，启动 seed，随游戏版本扩展） |
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

### 端点校验与限流矩阵（Round 13 审查定稿）

| 端点 | 限流（滑窗） | 入参硬边界 | 额外守卫 |
|---|---|---|---|
| POST `/users/register` | 10/min/IP（`REGISTER_RATE_LIMIT` 可调） | 昵称 ≤32 字符 strip | — |
| POST `/auth/refresh` | 300/min/IP | bearer 必须有效 | 旧 token 立即失效+缓存失效 |
| PUT `/progress` | 60/min/user + 3000/min/IP | state ≤256 KiB、updated_at ≤ now+5min | 成绩过 anticheat 三道门（天花板/节奏/静默隔离） |
| PUT `/records/{mode_id}` | 60/min/user + 3000/min/IP | best_score ≥0、mode 存在 | 同上；越门 422 |
| PUT `/missions` | 60/min/user + 3000/min/IP | week_key 0..1e9、progress ≥0 | — |
| POST `/achievements/{id}` | 60/min/user + 3000/min/IP | id ≤64 字符截断 | 幂等 |
| POST `/wallet/entries` | 30/min/user + 1500/min/IP | delta ±`MAX_WALLET_DELTA` | — |
| POST `/signin` | 10/min/user + 300/min/IP | day YYYY-MM-DD、streak 1..1e4 | 每日幂等 |
| GET `/leaderboard/{mode_id}` | — | period ∈ all/weekly/daily、limit ≤100 | 共享部分 Redis 缓存（总榜 30s/周期 15s） |

失败统一信封 `{"error":{"code":<http>,"detail":...}}`；429 同信封。
全表：9 张业务表 + schema_migrations；索引与慢查询实证见
`docs/backend-scale.md` §6.5（db_bench 全部热查询索引命中）。

## 部署与公网入口（已上线）

生产 API：**`https://lianliankan.zhaixingren.cn`**（游戏端常量 `server_sync.gd: DEFAULT_API_BASE`）。

```
浏览器(H5, GitHub Pages)
  → traefik :443（aigchub-001 上的 k3s，泛域名证书 *.zhaixingren.cn，acme.sh 自动续期）
  → Service/Endpoints → 172.22.246.76:30012（同机 sshd 反向隧道）
  → ssh-tunnel-lianliankan.service（local-server-001 上的 autossh，映射到 192.168.1.83:30800）
  → 家庭 K8S NodePort 30800 → lianliankan-backend Deployment（2 副本，namespace lianliankan）
  → PG/Redis（database namespace，连接见 config.yaml）
```

部署件：`deploy/k8s/`（家庭集群 namespace/config/deployment/service）+
`deploy/k8s/edge/`（autossh 隧道 unit + aigchub-001 k3s Ingress/Service/Endpoints 清单）。

镜像发布（Harbor 192.168.1.83:30050 为归一地址；Harbor 故障时把镜像
`docker save` 后在两台节点 `sudo ctr -n k8s.io images import` 直灌 containerd）：

```bash
rsync -a --exclude tests --exclude tools --exclude deploy backend/ local-server-001:/tmp/lianliankan-backend/
ssh local-server-001 'cd /tmp/lianliankan-backend && docker build -t 192.168.1.83:30050/tradermoney/lianliankan-backend:vN .'
# Harbor 可用: docker push；不可用: docker save | 两节点 ctr import
ssh local-server-001 'kubectl set image -n lianliankan deploy/lianliankan-backend api=192.168.1.83:30050/tradermoney/lianliankan-backend:vN'
```

2026-09-13 上线时的集群现状备忘：pod→Service（ClusterIP/域名）路径全断（kube-proxy 层，
同一场故障拖垮 Harbor——core 起不来自动降级）；期间 ConfigMap 临时用 `192.168.1.83:30432/30379`
NodePort 直连 PG/Redis，**集群 DNS 修复后把 config.yaml 改回集群内主机名**。
kube-proxy NodePort 不绑 127.0.0.1，隧道转发目标必须写节点 IP。

## 本地测试 + 覆盖率（秒级反馈，不用等 CI）

CI 要求行+分支双 100% 覆盖（--cov-fail-under=100），本地用一次性容器跑同一标准：

```bash
docker run -d --name llk-pg -e POSTGRES_USER=lianlian -e POSTGRES_PASSWORD=lianlian -e POSTGRES_DB=lianlian -p 15432:5432 postgres:16-alpine
docker run -d --name llk-redis -p 16379:6379 redis:7-alpine
export DATABASE_URL=postgresql://lianlian:lianlian@localhost:15432/lianlian REDIS_URL=redis://localhost:16379/0
# 覆盖率以全新库为准（迁移首跑行也计入覆盖），先清 schema 再跑：
docker exec llk-pg psql -U lianlian -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
python -m pytest tests -q --cov=app --cov-branch --cov-fail-under=100
```

注意：排行榜等有累积语义的用例已写成可重复执行；若复用旧库跑出顺序类失败，先清 schema。
pip 依赖：requirements.txt 全量 + pytest-cov。

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
| `ALLOWED_ORIGINS` | `https://lian-lian-kan.github.io` | CORS 允许的浏览器源（逗号分隔；游戏页搬家时改这里） |

默认值即 K8S 集群内主机名（`database` namespace，来源：local-server-001:~/k8s-service.txt）；
集群外跑本地开发时用 env 覆盖为 `local-server-002:30432` / `local-server-002:30379`。
`/healthz` 返回 `{"ok":true,"db":true,"redis":bool}`——PG 挂返回 503，Redis 挂仅降级限流不影响可用性。
