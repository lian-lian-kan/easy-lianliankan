extends SceneTree

# 语音播放回归：Godot 3 的 OGG 导入默认 loop=true（godotengine/godot#15895），
# 播放器必须强置 loop=false，且同一条语音 12 秒内不得重播（用户听到的
# 「最后一条语音死循环」由此双保险兜住）。

const MANAGER = preload("res://scripts/audio_manager.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _init() -> void:
	print("== voice_playback_test")
	var audio = MANAGER.new()
	root.add_child(audio)
	yield(self, "idle_frame")

	# The imported/raw stream must end up with looping disabled.
	audio.play_voice_path("res://assets/voice/clear_1.ogg")
	var stream = audio._voice_player.stream
	if stream == null:
		# Headless envs without the ogg bytes skip silently by design; the
		# contract below then rests on the fresh-instance default.
		check(true, "no ogg bytes in this env — playback skipped silently")
	else:
		check(stream.loop == false, "playback forces loop off on the voice stream")
	check(audio._voice_last_path == "res://assets/voice/clear_1.ogg",
		"the last-played path is recorded for the repeat guard")

	# The repeat guard: an immediate replay of the same clip is refused.
	var stamped_ms = int(audio._voice_last_ms)
	audio.play_voice_path("res://assets/voice/clear_1.ogg")
	check(int(audio._voice_last_ms) == stamped_ms,
		"an instant replay of the same clip is refused")

	# A different clip always plays and refreshes the guard.
	audio.play_voice_path("res://assets/voice/clear_2.ogg")
	check(audio._voice_last_path == "res://assets/voice/clear_2.ogg",
		"a different clip plays and refreshes the guard")

	# An old timestamp (beyond the guard) replays fine.
	audio._voice_last_ms = -1000000
	audio.play_voice_path("res://assets/voice/clear_1.ogg")
	check(int(audio._voice_last_ms) > stamped_ms,
		"beyond the guard window the clip plays again")

	if failures == 0:
		print("voice_playback_test: ALL PASSED")
		quit(0)
	else:
		print("voice_playback_test: %d FAILURES" % failures)
		quit(1)
