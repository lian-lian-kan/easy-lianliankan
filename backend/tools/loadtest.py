"""Load test for the sync/leaderboard hot path (real uvicorn required).

Start the API first, e.g.:
  DATABASE_URL=... REDIS_URL=... uvicorn app.main:app --port 8900
  python3 tools/loadtest.py --base http://127.0.0.1:8900 --users 200 --seconds 60

Each virtual user registers once, then loops the production mix: progress
push (with rising scores, exercising intake+anticheat), progress pull and a
leaderboard read. Prints per-endpoint RPS and latency percentiles.
"""
import argparse
import asyncio
import random
import time

import httpx


def _percentile(sorted_lat: list, frac: float) -> float:
    idx = min(int(len(sorted_lat) * frac), len(sorted_lat) - 1)
    return sorted_lat[idx] * 1000


async def _send(client: httpx.AsyncClient, method: str, url: str, **kwargs):
    """Request with one retry: long-lived keepalive connections occasionally
    die between server and client (RemoteProtocolError/ReadError) — that is
    transport noise, not server capacity."""
    try:
        return await client.request(method, url, **kwargs)
    except (httpx.ReadError, httpx.RemoteProtocolError, httpx.ConnectError):
        return await client.request(method, url, **kwargs)


async def _register(client: httpx.AsyncClient, base: str, idx: int,
                    register_lock: asyncio.Lock) -> dict:
    """Serial registration: every virtual user shares one source IP, so the
    register rate limit trips constantly — that is the server working as
    designed. One at a time with backoff gets everyone through."""
    async with register_lock:
        nickname = f"load-{idx % 50}-{random.randint(100000, 999999)}"
        for attempt in range(200):
            r = await _send(client, "POST", f"{base}/api/v1/users/register",
                            json={"nickname": nickname})
            if r.status_code == 429:
                await asyncio.sleep(min(30, 1 + attempt * 0.5) + random.random())
                continue
            r.raise_for_status()
            return r.json()
    raise RuntimeError("registration never succeeded")


async def user_loop(client: httpx.AsyncClient, base: str, idx: int,
                    deadline: float, stats: dict, latencies: dict,
                    register_lock: asyncio.Lock) -> None:
    user = await _register(client, base, idx, register_lock)
    headers = {"Authorization": f"Bearer {user['token']}"}
    score = random.randint(0, 400)
    rng = random.Random(idx)

    while time.monotonic() < deadline:
        score += rng.randint(10, 60)
        payload = {"state": {"coins": score, "zen_best_score": score,
                             "daily_challenge": {"best_score": 0}},
                   "updated_at": int(time.time() * 1000)}
        t0 = time.perf_counter()
        resp = await _send(client, "PUT", f"{base}/api/v1/progress",
                           json=payload, headers=headers)
        latencies["progress_put"].append(time.perf_counter() - t0)
        stats["progress_put"]["ok" if resp.status_code < 400 else "fail"] += 1
        if resp.status_code == 429:
            stats["progress_put"]["throttled"] += 1

        t0 = time.perf_counter()
        resp = await _send(client, "GET", f"{base}/api/v1/progress",
                           headers=headers)
        latencies["progress_get"].append(time.perf_counter() - t0)
        stats["progress_get"]["ok" if resp.status_code < 400 else "fail"] += 1
        if resp.status_code == 404:
            stats["progress_get"]["fail"] -= 1  # first pull before first save is legal
            stats["progress_get"]["ok"] += 1

        t0 = time.perf_counter()
        resp = await _send(client, "GET",
                           f"{base}/api/v1/leaderboard/zen?period=daily",
                           headers=headers)
        latencies["leaderboard"].append(time.perf_counter() - t0)
        stats["leaderboard"]["ok" if resp.status_code < 400 else "fail"] += 1

        await asyncio.sleep(rng.uniform(2.0, 4.0))


async def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1:8900")
    parser.add_argument("--users", type=int, default=200)
    parser.add_argument("--seconds", type=int, default=60)
    args = parser.parse_args()

    names = ["progress_put", "progress_get", "leaderboard"]
    stats = {name: {"ok": 0, "throttled": 0, "fail": 0} for name in names}
    latencies = {name: [] for name in names}

    limits = httpx.Limits(max_connections=args.users * 2,
                          max_keepalive_connections=args.users)
    register_lock = asyncio.Lock()
    async with httpx.AsyncClient(limits=limits,
                                 timeout=httpx.Timeout(10.0)) as client:
        deadline = time.monotonic() + args.seconds
        started = time.monotonic()
        await asyncio.gather(*[
            user_loop(client, args.base, i, deadline, stats, latencies,
                      register_lock)
            for i in range(args.users)])
        wall = time.monotonic() - started

    total_ok = sum(s["ok"] for s in stats.values())
    total_fail = sum(s["fail"] for s in stats.values())
    print(f"\n== loadtest: {args.users} users x {args.seconds}s → wall {wall:.1f}s")
    for name in names:
        lat = sorted(latencies[name]) or [0]
        s = stats[name]
        print(f"  {name:13s} ok={s['ok']:6d} fail={s['fail']:4d} "
              f"rps={s['ok'] / wall:7.1f} thr={s['throttled']:5d} "
              f"p50={_percentile(lat, 0.50):6.1f}ms "
              f"p95={_percentile(lat, 0.95):6.1f}ms "
              f"p99={_percentile(lat, 0.99):6.1f}ms")
    print(f"  TOTAL ok={total_ok} fail={total_fail} "
          f"rps={total_ok / wall:.1f} "
          f"error_rate={total_fail / max(1, total_ok + total_fail) * 100:.2f}%")


if __name__ == "__main__":
    asyncio.run(main())
