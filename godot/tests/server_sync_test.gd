extends SceneTree

# Unit tests for scripts/session/server_sync.gd — the cloud-save state
# machine: boot handshake decisions, adopt-newer semantics, throttle, and
# connection-banner transitions. Real network is pointed at a dead local
# port via LIANLIAN_API_BASE so nothing leaves the machine.

const SERVER_SYNC = preload("res://scripts/session/server_sync.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

class FakeGame extends Node:
	const PROGRESSION_SCRIPT = preload("res://scripts/session/progression.gd")
	var pull_http = null
	var sync_last_push_ms = 0
	var cloud_connected = false
	var sync_retry_timer = null
	var special_mode = ""
	var campaign_levels = [0, 1]
	var progression_state = PROGRESSION_SCRIPT.default_progress(2)
	var saved = 0
	var adopted = []
	var scheduled = 0
	var cancelled = 0
	var connected_banners = 0
	var missed_banners = 0
	func _save_progress_state():
		saved += 1
	func _on_sync_adopted(level_index):
		adopted.append(level_index)
	func _on_cloud_connected():
		connected_banners += 1
	func _on_cloud_miss():
		missed_banners += 1
	func _schedule_sync_retry():
		scheduled += 1
	func _cancel_sync_retry():
		cancelled += 1
	func _on_sync_request_completed(_result, code, _headers, body, kind):
		SERVER_SYNC.on_completed(self, kind, code, body.get_string_from_utf8())

func _forward(game, kind, code, body):
	game._on_sync_request_completed(0, code, null, body.to_utf8(), kind)

func _init() -> void:
	print("== server_sync_test")
	# CI runs headless tests with LIANLIAN_SYNC=0; flip it on locally and aim
	# the endpoint at a dead local port so no request ever leaves the machine.
	OS.set_environment("LIANLIAN_SYNC", "1")
	OS.set_environment("LIANLIAN_API_BASE", "http://127.0.0.1:1")

	check(SERVER_SYNC.enabled(), "sync enables when LIANLIAN_SYNC is not 0")
	check(SERVER_SYNC.base_url() == "http://127.0.0.1:1", "env override wins over the production constant")
	check(SERVER_SYNC.has_endpoint(), "an endpoint is configured")
	OS.set_environment("LIANLIAN_SYNC", "0")
	check(not SERVER_SYNC.enabled(), "LIANLIAN_SYNC=0 disables syncing entirely")
	OS.set_environment("LIANLIAN_SYNC", "1")

	# --- push throttle: a fresh push inside the window is a no-op
	var game = FakeGame.new()
	game.sync_last_push_ms = OS.get_ticks_msec()
	SERVER_SYNC.push(game)
	check(game.pull_http == null, "throttled push never reaches the wire")

	# --- register handshake: 201 stores the account and starts the pull
	game = FakeGame.new()
	_forward(game, "register", 201, '{"user_id":"u1","token":"t1"}')
	var meta = SERVER_SYNC._meta(game)
	check(str(meta["user_id"]) == "u1" and str(meta["token"]) == "t1", "register stores user_id and token")
	check(game.pull_http != null, "the pull lane starts right after registering")

	# --- register failure degrades to the retry path
	game = FakeGame.new()
	_forward(game, "register", 500, "{}")
	check(game.cloud_connected == false and game.scheduled == 1 and game.missed_banners == 1, "a failed register schedules the reconnect loop")

	# --- pull: 404 means a fresh cloud account, local save is the seed
	game = FakeGame.new()
	_forward(game, "pull", 404, '{"error":{"code":404,"detail":"no saved progress"}}')
	check(game.cloud_connected == true and game.cancelled == 1 and game.connected_banners == 1, "404 on pull connects without adopting")
	check(game.saved == 0 and game.adopted.empty(), "nothing is adopted from an empty account")

	# --- pull: strictly newer server save is adopted and re-saved
	game = FakeGame.new()
	game.progression_state["current_level_index"] = 0
	_forward(game, "pull", 200, '{"state":{"current_level_index":1},"updated_at":9999999999999}')
	check(game.progression_state["current_level_index"] == 1, "a newer server save overwrites the local state")
	check(game.saved == 1 and game.adopted == [1], "adoption re-saves locally and restarts at the server level")

	# --- pull: stale or equal server saves are ignored
	game = FakeGame.new()
	game.progression_state["current_level_index"] = 1
	_forward(game, "pull", 200, '{"state":{"current_level_index":0},"updated_at":1}')
	check(game.progression_state["current_level_index"] == 1 and game.saved == 0 and game.adopted.empty(), "a stale server save never clobbers the local state")

	# --- push: success records the synced stamp via the response
	game = FakeGame.new()
	SERVER_SYNC._write_meta(game, {"user_id": "u1", "token": "t1", "synced_at": 0})
	_forward(game, "push", 200, '{"saved":true,"updated_at":4242}')
	check(int(SERVER_SYNC._meta(game)["synced_at"]) == 4242, "a successful push records the server stamp")

	# --- push conflict: server holds a newer save -> synced_at stays low so
	# the next boot adopts the server copy
	game = FakeGame.new()
	SERVER_SYNC._write_meta(game, {"user_id": "u1", "token": "t1", "synced_at": 100})
	_forward(game, "push", 200, '{"saved":false,"updated_at":500}')
	check(int(SERVER_SYNC._meta(game)["synced_at"]) == 100, "a rejected push keeps the local stamp below the server's")
	_forward(game, "push", 422, "{}")
	check(game.cloud_connected == false and game.scheduled >= 1, "a hard push failure enters the reconnect loop")

	# --- meta round trip on disk
	game = FakeGame.new()
	SERVER_SYNC._write_meta(game, {"user_id": "u9", "token": "t9", "synced_at": 77})
	var round_trip = SERVER_SYNC._meta(game)
	check(str(round_trip["user_id"]) == "u9" and int(round_trip["synced_at"]) == 77, "sync meta persists beside the local save")

	OS.set_environment("LIANLIAN_SYNC", "0")
	var dir = Directory.new()
	if dir.file_exists("user://sync_meta.json"):
		dir.remove("user://sync_meta.json")

	if failures == 0:
		print("server_sync_test: ALL PASSED")
		quit(0)
	else:
		print("server_sync_test: %d FAILURES" % failures)
		quit(1)
