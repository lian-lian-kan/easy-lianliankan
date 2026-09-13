"""Sequential SQL migration runner tracked in schema_migrations."""
import os

from . import db

MIGRATIONS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "db", "migrations")


def apply_all() -> None:
    db.execute(
        "CREATE TABLE IF NOT EXISTS schema_migrations ("
        "version INT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT now())"
    )
    applied = {int(r["version"]) for r in db.query_all("SELECT version FROM schema_migrations")}
    for path in sorted(os.listdir(MIGRATIONS_DIR)):
        if not path.endswith(".sql"):
            continue
        version = int(path.split("_", 1)[0])
        if version in applied:
            continue
        with open(os.path.join(MIGRATIONS_DIR, path), encoding="utf-8") as fh:
            sql = fh.read()
        db.execute(sql)
        db.execute("INSERT INTO schema_migrations (version) VALUES (%s)", (version,))
