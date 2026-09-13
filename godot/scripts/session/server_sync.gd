extends Reference

# Server-side progress sync (opt-in). The game stays fully playable offline:
# without an API base URL every call is a no-op. Web builds enable it with the
# `?api=https://host` query parameter; fixed deploys can set DEFAULT_API_BASE.
#
# Account flow: on first sync the client registers against the backend and
# stores the returned user_id + bearer token beside the local save; the token
# is the credential, the server only keeps its SHA-256. Pushes carry the local
# progression blob with a client unix-ms timestamp; the server refuses stale
# timestamps so a newer save is never clobbered by an older device. On boot we
# pull once and adopt the server copy only when strictly newer.
#
# Request chaining: boot → register (first run only) → pull; saves → push.

const SYNC_META_PATH = "user://sync_meta.json"
const PUSH_THROTTLE_MS = 5000
const DEFAULT_API_BASE = ""

# Boot: register (first run only), then pull the server copy once.
static func boot_sync(game):
	var base = api_base()
	if base == "":
		return
	var meta = _meta(game)
	if str(meta.get("token", "")) == "":
		_request(game, "register", base + "/api/v1/users/register", HTTPClient.METHOD_POST, "{\"nickname\":\"\"}")
		return
	_pull(game, base, meta)

static func _pull(game, base, meta):
	_request(game, "pull", base + "/api/v1/progress", HTTPClient.METHOD_GET, "")

# Push the local progression blob (throttled); called after every local save.
static func push(game):
	var base = api_base()
	if base == "":
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
	_request(game, "push", base + "/api/v1/progress", HTTPClient.METHOD_PUT, body)

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
		print("[Sync] register failed: ", code)
		return
	var payload = parse_json(body_text)
	if payload == null or not payload.has("token"):
		return
	var meta = _meta(game)
	meta["user_id"] = str(payload["user_id"])
	meta["token"] = str(payload["token"])
	_write_meta(game, meta)
	_pull(game, api_base(), meta)

static func _on_pull(game, code, body_text):
	if code != 200:
		if code != 404:
			print("[Sync] pull failed: ", code)
		return
	var payload = parse_json(body_text)
	if payload == null or not payload.has("state"):
		return
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
		print("[Sync] push failed: ", code)
		return
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

static func api_base() -> String:
	if DEFAULT_API_BASE != "":
		return DEFAULT_API_BASE
	if OS.get_name() == "HTML5":
		var value = JavaScript.eval("new URLSearchParams(window.location.search).get('api') || ''", true)
		return str(value)
	return ""

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
