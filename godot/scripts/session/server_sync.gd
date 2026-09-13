extends Reference

# Cloud save — the game is cloud-first: on every boot it registers (first run
# only), pulls the server save and adopts it when strictly newer, and pushes
# after every local save (throttled). The local file is a cache; the server is
# the source of truth. A network miss never blocks play: the boot handshake
# retries on a timer until the cloud is reachable, and a quiet banner tracks
# the connection state.
#
# API endpoint: DEFAULT_API_BASE below is the single production constant.
# Local/dev overrides: env LIANLIAN_API_BASE; CI/headless tests: env
# LIANLIAN_SYNC=0 disables syncing entirely (no network in test runs).

const SYNC_META_PATH = "user://sync_meta.json"
const PUSH_THROTTLE_MS = 5000
const RETRY_SECONDS = 8.0

# 生产 API 根地址（HTTPS）。上线时把 DEFAULT_API_BASE 填成集群暴露的地址即可。
const DEFAULT_API_BASE = ""

# Boot: register (first run only), then pull the server copy once.
static func boot_sync(game):
	if not enabled():
		return
	var meta = _meta(game)
	if str(meta.get("token", "")) == "":
		_request(game, "register", base_url() + "/api/v1/users/register", HTTPClient.METHOD_POST, "{\"nickname\":\"\"}")
		return
	_pull(game, meta)

static func _pull(game, meta):
	_request(game, "pull", base_url() + "/api/v1/progress", HTTPClient.METHOD_GET, "")

# Push the local progression blob (throttled); called after every local save.
static func push(game):
	if not enabled():
		return
	var now = OS.get_ticks_msec()
	if now - int(game.sync_last_push_ms) < PUSH_THROTTLE_MS:
		return
	game.sync_last_push_ms = now
	var meta = _meta(game)
	if str(meta.get("token", "")) == "":
		return
	var stamp = _now_ms()
	meta["pending_stamp"] = stamp
	_write_meta(game, meta)
	var body = to_json({"state": game.progression_state, "updated_at": stamp})
	_request(game, "push", base_url() + "/api/v1/progress", HTTPClient.METHOD_PUT, body)

# Completion dispatch (HTTPRequest signals need Object targets, so the game
# shell forwards here with the lane kind).
static func on_completed(game, kind, code, body_text):
	match kind:
		"register":
			_on_register(game, code, body_text)
		"pull":
			_on_pull(game, code, body_text)
		"push":
			_on_push(game, code, body_text)

static func _on_register(game, code, body_text):
	if code != 201:
		return _cloud_miss(game, "register", code)
	var payload = parse_json(body_text)
	if payload == null or not payload.has("token"):
		return _cloud_miss(game, "register", -1)
	var meta = _meta(game)
	meta["user_id"] = str(payload["user_id"])
	meta["token"] = str(payload["token"])
	_write_meta(game, meta)
	_pull(game, meta)

static func _on_pull(game, code, body_text):
	if code == 404:
		# First contact with an empty cloud account: local cache is the seed.
		_cloud_ok(game)
		return
	if code != 200:
		return _cloud_miss(game, "pull", code)
	var payload = parse_json(body_text)
	if payload == null or not payload.has("state"):
		return _cloud_miss(game, "pull", -1)
	_cloud_ok(game)
	var server_stamp = int(payload.get("updated_at", 0))
	var meta = _meta(game)
	if server_stamp <= int(meta.get("synced_at", 0)):
		return
	var adopted = game.PROGRESSION_SCRIPT.normalize_progress(payload["state"], game.campaign_levels.size())
	game.progression_state = adopted
	meta["synced_at"] = server_stamp
	_write_meta(game, meta)
	game._save_progress_state()
	game._on_sync_adopted(int(adopted.get("current_level_index", 0)))
	print("[Sync] adopted server save @", server_stamp)

static func _on_push(game, code, body_text):
	if code != 200:
		return _cloud_miss(game, "push", code)
	var payload = parse_json(body_text)
	if payload == null:
		return
	var meta = _meta(game)
	if bool(payload.get("saved", false)):
		meta["synced_at"] = int(payload.get("updated_at", meta.get("pending_stamp", 0)))
	# else: server holds a newer save — leave synced_at alone so the next
	# boot pull adopts it (synced_at stays below the server stamp).
	meta.erase("pending_stamp")
	_write_meta(game, meta)

# Connection state: one banner change per transition, retry timer on a miss.
static func _cloud_ok(game):
	if not game.cloud_connected:
		game.cloud_connected = true
		game._on_cloud_connected()
	game._cancel_sync_retry()

static func _cloud_miss(game, lane, code):
	game.cloud_connected = false
	game._on_cloud_miss()
	game._schedule_sync_retry()
	print("[Sync] %s failed: %d — retry in %ss" % [lane, code, int(RETRY_SECONDS)])

static func enabled() -> bool:
	return OS.get_environment("LIANLIAN_SYNC") != "0"

# True when a production endpoint is configured (constant or env override).
static func has_endpoint() -> bool:
	return base_url() != ""

static func base_url() -> String:
	var from_env = OS.get_environment("LIANLIAN_API_BASE")
	if from_env != "":
		return from_env
	return DEFAULT_API_BASE

# A single shared HTTPRequest (requests are serialized by boot flow and the
# throttle); re-used for register/pull/push lanes.
static func _request(game, kind, url, method, body):
	var req = _http(game)
	if req.get_status() == HTTPRequest.STATUS_REQUESTING:
		return false
	var headers = ["Content-Type: application/json"]
	var meta = _meta(game)
	if str(meta.get("token", "")) != "":
		headers.append("Authorization: Bearer " + str(meta["token"]))
	return req.request(url, headers, false, method, body)

static func _http(game):
	if game.pull_http == null:
		var req = HTTPRequest.new()
		req.timeout = 8.0
		req.use_utf8 = true
		game.add_child(req)
		req.connect("request_completed", game, "_on_sync_request_completed")
		game.pull_http = req
	return game.pull_http

static func _meta(game):
	var meta = {"user_id": "", "token": "", "synced_at": 0}
	var file = File.new()
	if file.file_exists(SYNC_META_PATH):
		if file.open(SYNC_META_PATH, File.READ) == OK:
			var raw = parse_json(file.get_as_text())
			file.close()
			if raw != null and raw.has("token"):
				meta["user_id"] = str(raw.get("user_id", ""))
				meta["token"] = str(raw["token"])
				meta["synced_at"] = int(raw.get("synced_at", 0))
	return meta

static func _write_meta(game, meta):
	var file = File.new()
	if file.open(SYNC_META_PATH, File.WRITE) == OK:
		file.store_string(to_json(meta))
		file.close()

static func _now_ms() -> int:
	return int(OS.get_unix_time()) * 1000
