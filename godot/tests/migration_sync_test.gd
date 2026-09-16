extends SceneTree

# Unit tests for scripts/session/migration_sync.gd — pairing-code issue and
# claim handling over the shared sync meta — plus server_sync's 401
# self-heal that makes token expiry and post-migration revocation
# self-recovering (stale devices re-register instead of overwriting).

const SERVER_SYNC = preload("res://scripts/session/server_sync.gd")
const MIGRATION_SYNC = preload("res://scripts/session/migration_sync.gd")

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
	var migration_http = null
	var migration_code_label = null
	var migration_input = null
	var cloud_connected = false
	var sync_retry_timer = null
	var campaign_levels = [0, 1]
	var progression_state = PROGRESSION_SCRIPT.default_progress(2)
	var shown_code = []
	var failed_msgs = []
	var done_count = 0
	func _show_message(_text, _duration):
		pass
	func _on_migration_code_shown(code_text, expires_in):
		shown_code.append([code_text, expires_in])
	func _on_migration_failed(message):
		failed_msgs.append(message)
	func _on_migration_done():
		done_count += 1
	func _on_migration_request_completed(_result, code, _headers, body, kind):
		MIGRATION_SYNC.on_completed(self, kind, code, body.get_string_from_utf8())
	func _on_sync_request_completed(_result, code, _headers, body, kind):
		SERVER_SYNC.on_completed(self, kind, code, body.get_string_from_utf8())

func _init() -> void:
	print("== migration_sync_test")
	# Headless CI runs with sync off; flip it on and aim at a dead port so
	# nothing leaves the machine (same recipe as server_sync_test).
	OS.set_environment("LIANLIAN_SYNC", "1")
	OS.set_environment("LIANLIAN_API_BASE", "http://127.0.0.1:1")

	# ── Issue lane ──
	var game = FakeGame.new()
	MIGRATION_SYNC.on_completed(game, "mig_code", 200, '{"code":"ABCD-2345","expires_in":600}')
	check(game.shown_code.size() == 1 and game.shown_code[0][0] == "ABCD-2345", "issue 200 surfaces the code")
	check(int(game.shown_code[0][1]) == 600, "issue 200 carries the TTL")
	MIGRATION_SYNC.on_completed(game, "mig_code", 429, "")
	check(game.failed_msgs.size() == 1, "issue 429 degrades to a human message")

	# ── Claim success: fresh session, no stale pending_stamp, pull follows ──
	var fresh = FakeGame.new()
	SERVER_SYNC.store_meta(fresh, {"user_id": "throwaway", "token": "tok-old", "synced_at": 9, "pending_stamp": 123})
	MIGRATION_SYNC.on_completed(fresh, "mig_claim", 200, '{"user_id":"u1","token":"tok-new"}')
	var meta = SERVER_SYNC.read_meta(fresh)
	check(str(meta.get("token", "")) == "tok-new" and str(meta.get("user_id", "")) == "u1", "claim stores the adopted session")
	check(int(meta.get("synced_at", -1)) == 0, "adopted session resets synced_at")
	check(int(meta.get("pending_stamp", 0)) == 0, "adopted session drops the throwaway pending_stamp")
	check(fresh.done_count == 1, "claim success notifies the shell once")
	check(fresh.pull_http != null, "claim success kicks off the boot pull")

	# ── Claim failures map to human copy ──
	var a = FakeGame.new()
	MIGRATION_SYNC.on_completed(a, "mig_claim", 404, "")
	check(a.failed_msgs.size() == 1 and a.failed_msgs[0].find("重新生成") != -1, "404 asks for a fresh code")
	MIGRATION_SYNC.on_completed(a, "mig_claim", 409, "")
	check(a.failed_msgs.size() == 2, "409 reports an already-used code")
	MIGRATION_SYNC.on_completed(a, "mig_claim", 429, "")
	check(a.failed_msgs.size() == 3, "429 reports throttling")
	MIGRATION_SYNC.on_completed(a, "mig_claim", 200, "not-json")
	check(a.failed_msgs.size() == 4, "malformed 200 body degrades to a failure")

	# ── server_sync 401 self-heal: expired/revoked token re-registers ──
	var healed = FakeGame.new()
	SERVER_SYNC.store_meta(healed, {"user_id": "u9", "token": "dead-token", "synced_at": 5, "pending_stamp": 7})
	SERVER_SYNC.on_completed(healed, "pull", 401, "")
	var wiped = SERVER_SYNC.read_meta(healed)
	check(str(wiped.get("token", "")) == "" and str(wiped.get("user_id", "")) == "", "401 wipes the dead session")
	check(int(wiped.get("pending_stamp", 0)) == 0, "401 wipes the pending stamp too")
	check(healed.pull_http != null, "401 re-enters the boot register flow")

	# ── 401 self-heal with nothing stored: banner miss, no crash ──
	var bare = FakeGame.new()
	SERVER_SYNC.on_completed(bare, "push", 401, "")
	check(bare.cloud_connected == false, "401 without a session degrades to a miss")

	if failures == 0:
		print("ALL PASS")
	else:
		print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
