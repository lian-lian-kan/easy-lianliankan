# 服务端存档与后端体系（Server-side Progress & Backend）

2026-09-13：`backend/` 全量后端（FastAPI + PostgreSQL，分层 routers/services/core，
迁移化建表）。游戏在本地存档之上叠加云端账号体系与同步；默认纯离线，`?api=` 启用。

## 玩家视角

- **默认不变**：没有配置后端地址时，游戏 100% 离线。
- **启用方式（Web）**：URL 加 `?api=https://后端地址`；固定部署可写死
  `scripts/session/server_sync.gd` 的 `DEFAULT_API_BASE`。
- **账号**：首次同步自动向后端注册，浏览器保存 `user_id + token`
  （`user://sync_meta.json`）；改昵称/换设备迁移走后端账号体系。
- **同步规则**：启动拉取一次，服务器存档严格更新才采纳（并跳到对应战役进度）；
  每次本地存档后 5 秒节流推送；陈旧写被服务器拒绝；任何失败静默降级纯本地。

## 架构

```
godot (HTTPRequest, Bearer token)
  ├─ POST /api/v1/users/register     首次注册 → user_id + token
  ├─ GET  /api/v1/progress           启动拉取
  └─ PUT  /api/v1/progress           本地存档后推送（节流 5s）

backend/
  routers → services → core(db/security/migrations)
  9 张表：users / auth_tokens / progress_snapshots / modes / mode_records /
         achievements / missions_progress / economy_ledger / signin_log
```

- 表设计与迁移：`backend/db/migrations/00*.sql`（启动按版本自动应用，幂等）
- 后端 CI：`.github/workflows/backend.yml`（pg:16 service + pytest 真库全链测试），
  仅 `backend/**` 变更触发，不影响游戏 Pages 部署
- 客户端模块：`godot/scripts/session/server_sync.gd`（无 api 地址时全部 no-op）

## 接下来可接的游戏数据

后端已备好域表，游戏端逐项接入即可：玩法纪录上报（PUT records，排行榜立即可用）、
成就解锁、周任务进度、樱花币流水与签到。均走 Bearer token，幂等合并语义与客户端
本地策略一致（max/累加/每日一行）。

## 部署（参考）

```bash
cd backend && docker compose up -d --build
# 反向代理加 HTTPS（游戏页是 https，混合内容会被浏览器拦截）
# 然后游戏入口加 ?api=https://api.example.com
```

安全基线：令牌只存 SHA-256、90 天过期可轮换；`player_id`/token 枚举不可行；
上线前改掉 compose 默认 PG 口令并配置 TLS。
