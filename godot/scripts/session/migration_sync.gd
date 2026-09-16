extends Reference

# Device-to-device account migration over server-minted pairing codes.
# Old device: issue_code() shows a short-lived code bound to its account.
# New device: claim_code() burns the code, adopts the bound account
# (cloud-first: any fresh local progress yields to the migrated save) and
# the server revokes the old device's session. Lives outside server_sync so
# the periodic sync lanes stay serialized on their own shared HTTPRequest.

const SERVER_SYNC = preload("res://scripts/session/server_sync.gd")
const HTTP_TIMEOUT = 8.0

static func issue_code(game):
	var meta = SERVER_SYNC.read_meta(game)
	return _request(game, "mig_code", SERVER_SYNC.base_url() + "/api/v1/migration/code",
		HTTPClient.METHOD_POST, "{}", str(meta.get("token", "")))

static func claim_code(game, raw_code):
	var body = to_json({"code": raw_code})
	return _request(game, "mig_claim", SERVER_SYNC.base_url() + "/api/v1/migration/claim",
		HTTPClient.METHOD_POST, body, "")

static func on_completed(game, kind, code, body_text):
	if kind == "mig_code":
		_on_code(game, code, body_text)
	elif kind == "mig_claim":
		_on_claim(game, code, body_text)

static func _on_code(game, code, body_text):
	if code != 200:
		return game._on_migration_failed(_human(code))
	var payload = parse_json(body_text)
	if payload == null or not payload.has("code"):
		return game._on_migration_failed(_human(-1))
	game._on_migration_code_shown(str(payload["code"]), int(payload.get("expires_in", 0)))

static func _on_claim(game, code, body_text):
	if code != 200:
		return game._on_migration_failed(_human(code))
	var payload = parse_json(body_text)
	if payload == null or not payload.has("token"):
		return game._on_migration_failed(_human(-1))
	# Fresh session for the adopted account: no pending_stamp (the throwaway
	# local account's unsynced pushes must not leak into the new lineage)
	# and synced_at 0 so the very next boot pull adopts the migrated save.
	SERVER_SYNC.store_meta(game, {"user_id": str(payload["user_id"]), "token": str(payload["token"]), "synced_at": 0})
	game._on_migration_done()
	SERVER_SYNC.boot_sync(game)

static func _human(code):
	if code == 404:
		return "口令不存在或已过期，请回到旧设备重新生成"
	if code == 409:
		return "该口令已被使用过"
	if code == 410:
		return "口令已过期，请回到旧设备重新生成"
	if code == 429:
		return "尝试太频繁，请稍后再试"
	return "网络异常，请稍后再试"

static func _request(game, kind, url, method, body, token):
	var req = _http(game)
	var headers = ["Content-Type: application/json"]
	if token != "":
		headers.append("Authorization: Bearer " + token)
	return req.request(url, headers, false, method, body)

static func _http(game):
	var req = game.migration_http
	if req == null:
		req = HTTPRequest.new()
		req.timeout = HTTP_TIMEOUT
		game.add_child(req)
		req.connect("request_completed", game, "_on_migration_request_completed")
		game.migration_http = req
	return req
