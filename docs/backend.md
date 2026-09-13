# 服务端存档与后端体系（Server-side Progress & Backend）

2026-09-13：`backend/` 全量后端（FastAPI + PostgreSQL，分层 routers/services/core，
迁移化建表）。2026-09-14 定稿云端版：游戏始终同步云端，本地文件仅作缓存。

## 玩家视角（云端版设计，2026-09-14 定稿）

- **产品只有云端形态**：游戏启动即注册/拉取云端存档，本地文件只是缓存，服务器是唯一事实源。
- 接入点唯一：`server_sync.gd` 的 `DEFAULT_API_BASE`（生产地址）；本地开发用 env
  `LIANLIAN_API_BASE` 覆盖；CI 测试用 env `LIANLIAN_SYNC=0` 关网。
- **账号**：首次同步自动向后端注册，浏览器保存 `user_id + token`
  （`user://sync_meta.json`）；改昵称/换设备迁移走后端账号体系。
- **同步规则**：启动握手（注册→拉取），失败自动 8 秒重连（横幅「正在连接云端存档…」，连上提示「云端存档已连接」）；服务器存档严格更新才采纳并跳到对应战役进度；每次本地存档后 5 秒节流推送；陈旧写被服务器拒绝。

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

## 集群接入（K8S，2026-09-14 起）

- 生产 PG/Redis 跑在 K8S 集群 `database` namespace（集群信息见 local-server-001:~/k8s-service.txt）：
  - PG：`postgres.database.svc.cluster.local:5432`（库 `lianlian` 已建）
  - Redis：`redis.database.svc.cluster.local:6379`
- **连接一律用集群主机名，禁 IP**；集群外才用 `local-server-002` 的 NodePort（PG 30432 / Redis 30379）。
- 后端自身按 `backend/deploy/k8s/` 清单部署进集群（namespace `lianliankan`，2 副本，探活 /healthz）。
- 限流的滑动窗口存 Redis（ZSET），多副本共享；Redis 挂了自动降级内存窗口，API 不中断。

## 部署（已上线，2026-09-14）

- 生产 API：**`https://lianliankan.zhaixingren.cn`**（`server_sync.gd: DEFAULT_API_BASE`，已填）。
- 链路与发布步骤见 `backend/README.md` 的「部署与公网入口」；边缘清单在
  `backend/deploy/k8s/edge/`（autossh 隧道 + aigchub-001 k3s Ingress）。
- 首日上线备注：集群 pod→Service 通路故障期间，config.yaml 临时经 NodePort
  连 PG/Redis；集群 DNS 修复后改回集群内主机名（文件内已注明回退条件）。
- 本地开发仍可 `docker compose up`，env `LIANLIAN_API_BASE` 指到本地地址。
