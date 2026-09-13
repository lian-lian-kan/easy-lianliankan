# Sophia's lianliankan — Progress Backend

Python (FastAPI) + PostgreSQL 服务端存档。游戏端默认纯离线；配置 API 地址后自动
双向同步（启动拉取 + 存档推送，带节流与陈旧写入拒绝）。

## 身份模型

免登录：客户端首次运行生成 32 位 hex `player_id`（存 `user://sync_meta.json`），
id 即凭证。休闲游戏无 PII；换浏览器/清存档 = 新账号。同一 id 多设备共享进度，
按 `updated_at` 时间戳后者胜，服务器拒绝更旧的写入（409 语义通过响应体 `saved:false` 表达）。

## API

| Method | Path | 说明 |
|---|---|---|
| GET | `/healthz` | 存活检查 |
| GET | `/api/v1/progress/{player_id}` | 读取，404=无存档 |
| PUT | `/api/v1/progress/{player_id}` | 写入 `{state, updated_at}`，返回 `{saved, updated_at}` |

- `player_id`：32 位 hex，否则 400。
- `state`：游戏 progression_state 整包 JSON，>256KB 拒绝（413）。
- 陈旧写入：`updated_at` 小于已存值时**不落库**，返回 `{saved:false, updated_at:服务器值}`。

## 本地起服务

```bash
cd backend
docker compose up --build   # api :8000 + postgres
curl localhost:8000/healthz
```

## 测试（需要 PostgreSQL）

```bash
export DATABASE_URL=postgresql://lianlian:lianlian@localhost:5432/lianlian
pip install -r requirements.txt
python -m pytest tests -q          # CI 的 backend workflow 已带 pg service
SKIP_PG_TESTS=1 跳过 DB 用例
```

## 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `DATABASE_URL` | `postgresql://lianlian:lianlian@localhost:5432/lianlian` | PG 连接串 |
| `MAX_STATE_BYTES` | `262144` | state 体积上限 |
| `PG_POOL_MIN` / `PG_POOL_MAX` | 1 / 8 | 连接池 |

## 表结构

见 `schema.sql`（应用启动时自动建表，幂等）。
