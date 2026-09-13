"""Sophia's lianliankan backend — app assembly.

Layering: routers (HTTP) -> services (business rules) -> repositories (SQL)
-> core (db/transactions/security/migrations/ratelimit). All errors leave as
a JSON envelope; every response carries an X-Request-Id and requests are
logged with their id, status and duration.
"""
import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .core import config, db, migrations, redis_client
from .core.guards import new_request_id
from .routers import auth, engagement, progress, records, users
from .core.mode_seed import MODES
from .services import records_service

logger = logging.getLogger("lianliankan")
logging.basicConfig(level=logging.INFO, format="%(message)s")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    db.init_pool()
    migrations.apply_all()
    records_service.seed_modes(MODES)
    yield
    db.close_pool()


app = FastAPI(title="sophia-lianliankan-backend", version="2.1", lifespan=lifespan)

# The H5 page on GitHub Pages calls this API cross-origin; PUT/POST trigger a
# browser preflight that must be answered here, not by the routers.
app.add_middleware(
    CORSMiddleware,
    allow_origins=config.allowed_origins(),
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Request-Id"],
    max_age=600,
)


@app.get("/healthz")
def healthz():
    db_ok = db.ping()
    if not db_ok:
        return JSONResponse(status_code=503, content={"ok": False, "db": False})
    return {"ok": True, "db": True, "redis": redis_client.ping()}


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    request_id = getattr(request.state, "request_id", "-")
    logger.info('{"rid":"%s","event":"http_error","status":%d,"detail":"%s"}',
                request_id, exc.status_code, exc.detail)
    return JSONResponse(status_code=exc.status_code,
                        content={"error": {"code": exc.status_code, "detail": str(exc.detail)}})


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    request_id = getattr(request.state, "request_id", "-")
    logger.exception('{"rid":"%s","event":"unhandled_error"}', request_id)
    return JSONResponse(status_code=500,
                        content={"error": {"code": 500, "detail": "internal error"}})


@app.middleware("http")
async def request_context(request: Request, call_next):
    request.state.request_id = request.headers.get("X-Request-Id") or new_request_id()
    started = time.monotonic()
    response = await call_next(request)
    response.headers["X-Request-Id"] = request.state.request_id
    logger.info('{"rid":"%s","event":"request","method":"%s","path":"%s","status":%d,"ms":%.1f}',
                request.state.request_id, request.method, request.url.path,
                response.status_code, (time.monotonic() - started) * 1000)
    return response


app.include_router(users.router)
app.include_router(auth.router)
app.include_router(progress.router)
app.include_router(records.router)
app.include_router(engagement.router)
