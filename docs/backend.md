# 服务端存档（Server-side Progress）

2026-09-13 起：游戏在本地存档之上增加可选的服务端同步（`backend/`，FastAPI + PostgreSQL）。

## 玩家视角

- **默认不变**：没有配置后端地址时，游戏 100% 离线，行为与以前完全一致。
- **启用方式（Web）**：在游戏 URL 后加 `?api=https://你的后端地址`，例如
  `https://xxx.github.io/easy-lianliankan/?api=https://api.example.com`。
  部署方可把固定后端写死在 `scripts/session/server_sync.gd` 的 `DEFAULT_API_BASE`。
- **同步规则**：
  - 启动时拉取一次：服务器存档**严格更新**（`updated_at` 更大）才覆盖本地，并直接跳到对应的战役进度；
  - 每次本地存档后推送（5 秒节流）；
  - 服务器拒绝更旧的写入（防旧设备覆盖新档），任何网络失败都静默降级为纯本地。
- **账号**：免登录，首次运行自动生成 32 位设备 id。清除浏览器数据 = 新账号。

## 架构

```
godot (HTTPRequest)
  ├─ GET  /api/v1/progress/{player_id}   启动拉取
  └─ PUT  /api/v1/progress/{player_id}   本地存档后推送（节流 5s）
backend FastAPI ── PostgreSQL (player_progress: player_id PK / state JSONB / updated_at)
```

- 代码：`backend/app/`（`main.py` 路由、`store.py` 持久化、`config.py` 环境变量）
- 表结构：`backend/schema.sql`（启动自动创建）
- 后端测试：`.github/workflows/backend.yml`（pg service + pytest），只在 `backend/**` 变更时触发，不影响游戏 Pages 部署流水线
- 前端模块：`godot/scripts/session/server_sync.gd`（无 API 地址时全部 no-op，headless 测试零影响）

## 部署（参考）

```bash
cd backend && docker compose up -d --build
# 反向代理加 HTTPS（游戏页是 https，混合内容会被浏览器拦截 —— api 必须同为 https）
# 然后游戏入口加 ?api=https://api.example.com
```

安全基线：只暴露 `/healthz` 与两个 progress 端点；`player_id` 即凭证（暴力枚举 128-bit 空间不可行）；
上线前把 compose 里的默认 PG 口令改掉并加 TLS 终端。
