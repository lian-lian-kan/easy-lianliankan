# K8S 部署（lianliankan-backend）

镜像内已内置集群内服务主机名（`postgres.database.svc.cluster.local` /
`redis.database.svc.cluster.local`，见 deploy/k8s/config.yaml），**全程主机名、无 IP**。

## 前置（已完成）

- 集群 `database` namespace 里 PG(`postgres-0`) 与 Redis(`redis-0`) 就绪；
- 已在集群 PG 建 `lianlian` 库（表由后端启动迁移自动创建）。

## 构建并导入镜像

集群用 local-path 本地盘、无镜像仓库时，在构建机上：

```bash
cd backend
docker build --platform linux/amd64 -t lianliankan-backend:latest .
docker save lianliankan-backend:latest | gzip > /tmp/lianliankan-backend.tar.gz
scp /tmp/lianliankan-backend.tar.gz local-server-001:/tmp/
ssh local-server-001 'gunzip -c /tmp/lianliankan-backend.tar.gz | sudo docker load'
```

（`local-server-001`/`local-server-002` 是集群两个 worker；containerd 运行时的集群
改用 `ctr -n k8s.io images import`。）

## 部署 / 升级

```bash
kubectl apply -f deploy/k8s/namespace.yaml
kubectl apply -f deploy/k8s/config.yaml
kubectl apply -f deploy/k8s/deployment.yaml
kubectl apply -f deploy/k8s/service.yaml
kubectl -n lianliankan rollout status deployment/lianliankan-backend
```

## 验证

```bash
kubectl -n lianliankan get pods -o wide
kubectl -n lianliankan run curl --rm -it --image=curlimages/curl -- \
  curl -s http://lianliankan-backend/healthz
# 期望 {"ok":true,"db":true,"redis":true}
```

## 游戏侧接入

- 集群外：给 Service 挂 NodePort 或经 Ingress 暴露，游戏 URL 加
  `?api=https://<对外地址>`；
- 集群内：直接 `http://lianliankan-backend.lianliankan.svc.cluster.local`。

## 扩缩容

`replicas: 2` 起步；限流已走共享 Redis（ZSET），多副本全局限流天然生效——
某副本挂了只降级为内存限流（本地窗口），不影响正确性。
