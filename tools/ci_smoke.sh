#!/bin/bash
# Headless browser smoke test: boot the exported game in headless Chrome
# (?smoke=1) and detect the boot beacon fired by setStatusMode('hidden').
# Real-time wait — no DOM dumping, robust against virtual-time flakiness.
# Usage: tools/ci_smoke.sh [export_dir]   (default: public/godot)
# Env overrides: CHROME (browser binary), SMOKE_PORT, SMOKE_WAIT (seconds).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXPORT_DIR="${1:-$ROOT/public/godot}"
PORT="${SMOKE_PORT:-8099}"
WAIT="${SMOKE_WAIT:-90}"
LOG="$(mktemp /tmp/smoke_beacon.XXXX.log)"
SERVER_PY="$(mktemp /tmp/smoke_server.XXXX.py)"

cat > "$SERVER_PY" <<'PYEOF'
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler

port, export_dir, log_path = sys.argv[1], sys.argv[2], sys.argv[3]

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=export_dir, **kwargs)

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        self.rfile.read(length)
        with open(log_path, "a") as f:
            f.write("BEACON " + self.path + "\n")
        self.send_response(204)
        self.end_headers()

    def log_message(self, fmt, *args):
        with open(log_path, "a") as f:
            f.write("REQ " + (fmt % args) + "\n")

HTTPServer(("127.0.0.1", int(port)), Handler).serve_forever()
PYEOF

if [ ! -f "$EXPORT_DIR/index.pck" ] || [ ! -f "$EXPORT_DIR/index.wasm" ]; then
    echo "SMOKE FAILED: $EXPORT_DIR is missing index.pck/index.wasm (export first)"
    rm -f "$SERVER_PY"
    exit 1
fi

CHROME="${CHROME:-}"
if [ -z "$CHROME" ]; then
    for candidate in google-chrome google-chrome-stable chromium-browser chromium \
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; do
        if command -v "$candidate" >/dev/null 2>&1 || [ -x "$candidate" ]; then
            CHROME="$candidate"
            break
        fi
    done
fi
if [ -z "$CHROME" ]; then
    echo "SMOKE FAILED: no Chrome/Chromium found (set CHROME=...)"
    rm -f "$SERVER_PY"
    exit 1
fi

python3 "$SERVER_PY" "$PORT" "$EXPORT_DIR" "$LOG" &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null || true; rm -f "$SERVER_PY"' EXIT
sleep 1

START=$(date +%s)
"$CHROME" --headless --no-sandbox --disable-dev-shm-usage --disable-gpu \
    "http://127.0.0.1:$PORT/index.html?smoke=1" >/dev/null 2>&1 &
CHROME_PID=$!

BOOTED=0
while [ $(( $(date +%s) - START )) -lt "$WAIT" ]; do
    if grep -q "BEACON /smoke-boot-ok" "$LOG" 2>/dev/null; then
        BOOTED=1
        break
    fi
    if ! kill -0 "$CHROME_PID" 2>/dev/null; then
        break
    fi
    sleep 2
done
kill "$CHROME_PID" 2>/dev/null || true
ELAPSED=$(( $(date +%s) - START ))

if [ "$BOOTED" = "1" ]; then
    echo "SMOKE OK: engine booted in ${ELAPSED}s (boot beacon received), loading overlay removed"
    rm -f "$SERVER_PY" "$LOG"
    exit 0
fi
echo "SMOKE FAILED: no boot beacon within ${WAIT}s"
echo "--- server log tail ---"
tail -5 "$LOG" 2>/dev/null || true
rm -f "$SERVER_PY" "$LOG"
exit 1
