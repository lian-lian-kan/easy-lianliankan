extends Reference

# Server-side progress sync (opt-in). The game stays fully playable offline:
# without an API base URL every call is a no-op. Web builds enable it with the
# `?api=https://host` query parameter; fixed deploys can set DEFAULT_API_BASE.
#
# Strategy: the client mints a random 32-hex player id once (stored beside the
# local save) and treats it as the account. Pushes carry the local save with a
# client unix-ms timestamp; the server refuses stale timestamps, so a newer
# save is never clobbered by an older device. On boot we pull once and adopt
# the server copy only when it is strictly newer than the last synced stamp.

const SYNC_META_PATH = "user://sync_meta.json"
const PUSH_THROTTLE_MS = 5000
const DEFAULT_API_BASE = ""

# Boot: pull the server copy once; adopt it when strictly newer, then restart
# the campaign level so the adopted current_level_index takes effect.
static func boot_sync(game):
	var base = api_base()
	if base == "":
		return
	var meta = _meta(game)
	var url = base + "/api/v1/progress/" + str(meta["player_id"])
	var req = _http(game, "pull_http")
	if req.get_status() == HTTPRequest.STATUS_REQUESTING:
		return
	if not req.request(url, [], false, HTTPClient.METHOD_GET):
		return
	print("[Sync] boot pull -> ", url)


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
	var stamp = _now_ms()
	meta["pending_stamp"] = stamp
	_write_meta(game, meta)
	var body = to_json({"state": game.progression_state, "updated_at": stamp})
	var url = base + "/api/v1/progress/" + str(meta["player_id"])
	var req = _http(game, "push_http")
	if req.get_status() == HTTPRequest.STATUS_REQUESTING:
		return
	req.request(url, ["Content-Type: application/json"], false, HTTPClient.METHOD_PUT, body)


# Completion callback wiring (HTTPRequest signals need Object targets, so the
# game shell forwards here with the node kind).
static func on_completed(game, kind, result, code, body_text):
	if kind == "pull":
		_on_pull(game, code, body_text)
	else:
		_on_push(game, code, body_text)


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


static func _http(game, member):
	if game.get(member) == null:
		var req = HTTPRequest.new()
		req.timeout = 8.0
		req.use_utf8 = true
		game.add_child(req)
		var kind = "pull" if member == "pull_http" else "push"
		req.connect("request_completed", game, "_on_sync_request_completed", [kind])
		game.set(member, req)
	return game.get(member)


static func _meta(game):
	var meta = {"player_id": "", "synced_at": 0}
	var file = File.new()
	if file.file_exists(SYNC_META_PATH):
		if file.open(SYNC_META_PATH, File.READ) == OK:
			var raw = parse_json(file.get_as_text())
			file.close()
			if raw != null and raw.has("player_id"):
				meta["player_id"] = str(raw["player_id"])
				meta["synced_at"] = int(raw.get("synced_at", 0))
	if str(meta["player_id"]).length() != 32:
		meta["player_id"] = _fresh_player_id()
		_write_meta(game, meta)
	return meta


static func _write_meta(game, meta):
	var file = File.new()
	if file.open(SYNC_META_PATH, File.WRITE) == OK:
		file.store_string(to_json(meta))
		file.close()


static func _fresh_player_id() -> String:
	var id = ""
	for _i in range(32):
		id += "%x" % _rand_hex_digit()
	return id


static func _rand_hex_digit() -> int:
	return randi() % 16
