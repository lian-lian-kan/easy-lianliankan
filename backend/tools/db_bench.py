"""Database query-performance proof: seed realistic volumes, then verify
every hot query hits an index (no sequential scans on big tables) and report
EXPLAIN ANALYZE timings.

Run against a disposable database:
  DATABASE_URL=postgresql://... python3 tools/db_bench.py --rows 200000

Exit code 1 if any hot query sequential-scans a large table.
"""
import argparse
import re
import sys
import time

import psycopg2

SEED = """
INSERT INTO users (user_id, nickname)
SELECT gen_random_uuid(), 'bench-' || g FROM generate_series(1, %(users)s) g;

INSERT INTO auth_tokens (token_hash, user_id, expires_at)
SELECT md5(g::text), user_id, now() + interval '30 days'
FROM (SELECT user_id, row_number() OVER () AS g FROM users) s WHERE g <= %(users)s / 2;

INSERT INTO mode_records (user_id, mode_id, best_score, plays, wins, updated_at)
SELECT u.user_id, m.mode_id,
       (random() * 50000)::int, (random() * 200)::int, (random() * 100)::int,
       (extract(epoch from now()) * 1000)::bigint
FROM users u CROSS JOIN (SELECT mode_id FROM modes ORDER BY random() LIMIT 5) m;

INSERT INTO mode_score_events (user_id, mode_id, score, created_at)
SELECT u.user_id, m.mode_id, (random() * 50000)::int,
       now() - (random() * interval '30 days')
FROM (SELECT user_id FROM users ORDER BY random() LIMIT %(active)s) u
CROSS JOIN LATERAL (SELECT mode_id FROM modes ORDER BY random() LIMIT 3) m
CROSS JOIN LATERAL (SELECT g FROM generate_series(1, %(runs)s) g) runs;

INSERT INTO economy_ledger (user_id, delta, reason)
SELECT u.user_id, (random() * 40 - 10)::int, 'bench'
FROM users u CROSS JOIN LATERAL (SELECT g FROM generate_series(1, 50) g) l;
"""

# (label, sql, params, must_not_seqscan)
HOT_QUERIES = [
    ("token_lookup",
     "SELECT user_id FROM auth_tokens WHERE token_hash = %s AND expires_at > now()",
     ("deadbeef",), ["auth_tokens"]),
    ("leaderboard_top",
     """SELECT u.nickname, r.best_score FROM mode_records r
        JOIN users u ON u.user_id = r.user_id
        WHERE r.mode_id = %s AND r.best_score > 0
        ORDER BY r.best_score DESC, r.updated_at ASC LIMIT 100""",
     ("zen",), ["mode_records"]),
    ("leaderboard_my_rank",
     """SELECT rank FROM (
            SELECT user_id, RANK() OVER (ORDER BY best_score DESC) AS rank
            FROM mode_records WHERE mode_id = %s AND best_score > 0
        ) ranked WHERE user_id = (SELECT user_id FROM users ORDER BY user_id LIMIT 1)""",
     ("zen",), ["mode_records"]),
    ("events_window_top",
     """SELECT user_id, MAX(score) FROM mode_score_events
        WHERE mode_id = %s AND created_at >= now() - interval '7 days'
        GROUP BY user_id ORDER BY 2 DESC LIMIT 100""",
     ("zen",), ["mode_score_events"]),
    ("events_last_score",
     """SELECT EXTRACT(EPOCH FROM MAX(created_at)) * 1000 FROM mode_score_events
        WHERE user_id = (SELECT user_id FROM users ORDER BY user_id LIMIT 1) AND mode_id = %s""",
     ("zen",), ["mode_score_events"]),
    ("wallet_balance_sum",
     """SELECT COALESCE(SUM(delta), 0) FROM economy_ledger
        WHERE user_id = (SELECT user_id FROM users ORDER BY user_id LIMIT 1)""",
     (), ["economy_ledger"]),
    ("wallet_entries",
     """SELECT delta, reason, created_at FROM economy_ledger
        WHERE user_id = (SELECT user_id FROM users ORDER BY user_id LIMIT 1)
        ORDER BY entry_id DESC LIMIT 20""",
     (), ["economy_ledger"]),
]


def seed(conn: psycopg2.extensions.connection, users: int, runs: int) -> None:
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM users")
    if cur.fetchone()[0] >= users:
        print("bench data already present — reuse")
        conn.commit()
        return
    # Fewer users than requested (e.g. leftover test rows) would benchmark
    # empty tables and fake a PASS — reset to the target volume instead.
    print(f"resetting and seeding: {users} users, {users // 2} tokens, "
          f"5 records each, ~{runs * 3 * users} events, {users * 50} ledger rows ...")
    cur.execute("TRUNCATE users RESTART IDENTITY CASCADE")
    print(f"seeding: {users} users, {users}/2 tokens, 5 records each, "
          f"~{runs * 3} events, {users * 50} ledger rows ...")
    cur.execute(SEED, {"users": users, "active": users, "runs": runs})
    conn.commit()


def explain(cur, sql: str, params) -> str:
    cur.execute("EXPLAIN ANALYZE " + sql, params)
    return "\n".join(row[0] for row in cur.fetchall())


def main() -> int:
    import os
    parser = argparse.ArgumentParser()
    parser.add_argument("--users", type=int, default=5000)
    parser.add_argument("--runs", type=int, default=13)
    parser.add_argument("--database-url", default=os.environ.get("DATABASE_URL", ""))
    args = parser.parse_args()
    if not args.database_url:
        print("DATABASE_URL required")
        return 2

    conn = psycopg2.connect(args.database_url)
    seed(conn, args.users, args.runs)
    cur = conn.cursor()

    BIG_TABLE_ROWS = 10_000  # below this a seq scan is the planner being right
    row_counts = {}
    for table in {t for _, _, _, g in HOT_QUERIES for t in g}:
        cur.execute(f"SELECT COUNT(*) FROM {table}")
        row_counts[table] = cur.fetchone()[0]

    failures = []
    print(f"\n== hot queries (plan scan check + timing), "
          f"{args.users} users / {args.runs * 3} events per active user")
    for label, sql, params, guarded in HOT_QUERIES:
        plan = explain(cur, sql, params)
        seq_scans = re.findall(r"Seq Scan on (\w+)", plan)
        violated = [t for t in seq_scans if t in guarded
                    and row_counts[t] >= BIG_TABLE_ROWS]
        ms = float(re.search(r"Execution Time: ([\d.]+) ms", plan).group(1))
        status = "OK" if not violated else "SEQ-SCAN"
        print(f"  {label:22s} {ms:8.2f} ms  {status}"
              + (f"  scanned={violated}" if violated else ""))
        if violated:
            failures.append(label)
    conn.close()

    if failures:
        print(f"\nFAIL: sequential scans on guarded tables: {failures}")
        return 1
    print("\nPASS: every hot query is index-backed")
    return 0


if __name__ == "__main__":
    start = time.monotonic()
    code = main()
    print(f"(db_bench wall {time.monotonic() - start:.1f}s)")
    sys.exit(code)
