extends Node

# Audio players dictionary
var _players: Dictionary = {}

# Audio settings
var master_volume: float = 0.7
var effects_enabled: bool = true
var music_enabled: bool = true
var voice_enabled: bool = true
var muted: bool = false

# Voice line playback: one dedicated player (a new clip interrupts the
# previous one) and a stream cache. Loading is fault-tolerant — the headless
# test env has no ogg import cache, so a failed load just means silence.
# Godot 3's OGG importer bakes loop=true into imported streams by default
# (godotengine/godot#15895), so playback force-clears the loop flag and a
# same-clip guard keeps a line from ever feeling stuck on repeat.
var _voice_player: AudioStreamPlayer = null
var _voice_cache: Dictionary = {}
var _voice_last_path: String = ""
var _voice_last_ms: int = -1000000
const VOICE_REPEAT_GUARD_MS = 12000

# Sound effect streams (using procedural audio or simple beeps for web compatibility)
var _sounds: Dictionary = {}

# Background music player
var _bgm_player: AudioStreamPlayer = null
var _bgm_timer: Timer = null
var _bgm_step: int = 0

# Sound-effect catalog (Round 40): WHAT each event sounds like lives in
# content/sfx.gd as data — variant pools drawn through shuffled decks so
# repeats stay rare. This autoload only renders recipes; the play_* wrappers
# stay for the existing call sites.
const SFX_CATALOG = preload("res://scripts/content/sfx.gd")
var sfx_decks: Dictionary = {}

func _ready() :
	_load_settings()
	_initialize_sounds()
	_bgm_timer = Timer.new()
	_bgm_timer.one_shot = true
	_bgm_timer.connect("timeout", self, "_play_next_bgm_note")
	add_child(_bgm_timer)
	_voice_player = AudioStreamPlayer.new()
	_voice_player.volume_db = -2.0
	add_child(_voice_player)

func _load_settings() :
	# Try to load from config file
	var config = ConfigFile.new()
	var err = config.load("user://audio_settings.cfg")
	if err == OK:
		master_volume = config.get_value("audio", "master_volume", 0.7)
		effects_enabled = config.get_value("audio", "effects_enabled", true)
		music_enabled = config.get_value("audio", "music_enabled", true)
		voice_enabled = config.get_value("audio", "voice_enabled", true)
		muted = config.get_value("audio", "muted", false)

func save_settings() :
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "effects_enabled", effects_enabled)
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("audio", "voice_enabled", voice_enabled)
	config.set_value("audio", "muted", muted)
	config.save("user://audio_settings.cfg")

func _initialize_sounds() :
	# Create procedural sound effects using Godot's built-in capabilities
	# For web export, we use simple tone generation instead of external audio files
	pass

func _build_tone_stream(frequency: float, duration: float) :
	var sample_rate: int = 44100
	var frame_count: int = max(1, int(round(duration * sample_rate)))
	var amplitude: float = 0.28
	var pcm: PoolByteArray = PoolByteArray()
	pcm.resize(frame_count * 2)  # 16-bit mono

	var phase: float = 0.0
	var phase_step: float = TAU * frequency / float(sample_rate)
	# 音色包络（Round 40）：6ms 起音消掉裸正弦的爆音咔嗒，尾段 35% 抛物线
	# 收束；叠加二/三次泛音把「冷硬蜂鸣」变成柔和的钟琴质感。
	var attack_frames: int = max(1, int(round(0.006 * sample_rate)))
	var decay_start: int = int(float(frame_count) * 0.65)
	var decay_len: float = float(max(1, frame_count - decay_start))
	for i in range(frame_count):
		var env: float = 1.0
		if i < attack_frames:
			env = float(i) / float(attack_frames)
		elif i >= decay_start:
			var t: float = float(i - decay_start) / decay_len
			env = 1.0 - 0.9 * (t * t)
		var sample_value: int = int(round((sin(phase) + 0.32 * sin(2.0 * phase) + 0.1 * sin(3.0 * phase)) * env * amplitude * 32767.0))
		sample_value = int(clamp(sample_value, -32768, 32767))
		var unsigned_value: int = sample_value & 0xffff
		pcm[i * 2] = unsigned_value & 0xff
		pcm[i * 2 + 1] = (unsigned_value >> 8) & 0xff
		phase += phase_step

	var stream: AudioStreamSample = AudioStreamSample.new()
	stream.format = AudioStreamSample.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_begin = 0
	stream.loop_end = 0
	stream.data = pcm
	return stream

func _create_tone_player(frequency: float, duration: float, volume_db: float = -10.0) :
	var player = AudioStreamPlayer.new()
	var master_db: float = linear2db(float(max(master_volume, 0.001)))
	player.stream = _build_tone_stream(frequency, duration)
	player.volume_db = (volume_db + master_db) if not muted else -80.0
	add_child(player)
	return player

func _play_tone(frequency: float, duration: float, volume_db: float = -10.0) :
	if muted or not effects_enabled:
		return

	var player = _create_tone_player(frequency, duration, volume_db)
	player.play()

	# Auto-cleanup after playing
	yield(get_tree().create_timer(duration + 0.1), "timeout")
	player.queue_free()

# Public API for playing sound effects — thin wrappers over the catalog
# (content/sfx.gd owns the recipes; each event rotates through its variant
# pool via shuffled decks, so consecutive hits never sound identical).

func _play_event(key: String):
	if muted or not effects_enabled:
		return
	var recipe = SFX_CATALOG.draw(self, key)
	for note in recipe:
		_play_tone(float(note[0]), float(note[1]), float(note[2]))
		if float(note[3]) > 0.0:
			yield(get_tree().create_timer(float(note[3])), "timeout")

func play_select() :
	_play_event("select")

func play_eliminate() :
	_play_event("eliminate")

func play_eliminate_combo(combo: int) :
	_play_event(SFX_CATALOG.key_for_combo(combo))

func play_error() :
	_play_event("error")

func play_hint() :
	_play_event("hint")

func play_win() :
	_play_event("win")

func play_button_click() :
	_play_event("click")

func play_shuffle() :
	_play_event("shuffle")

func play_combo(combo_level: int) :
	_play_event(SFX_CATALOG.key_for_combo(combo_level))

func play_time_warning() :
	_play_event("time_warning")

func play_fail() :
	_play_event("fail")

# Reward chime (new event): blossoms/coins landing — paid at milestones,
# mission claims and achievement unlocks.
func play_coin() :
	_play_event("coin")

# Power-up armed: soft mystical rise (distinct from the plain click).
func play_powerup() :
	_play_event("powerup")

# Background Music (Round 41): bass + arpeggio bars from the catalog
# (content/sfx.gd MUSIC_SECTIONS), two sections rotating so the loop
# breathes. The scheduler walks one bar per tick: sustain the bass while
# arpeggiating the chord tones.

func start_bgm() :
	if not music_enabled or muted:
		return
	_bgm_step = 0
	_play_next_bgm_note()

func stop_bgm() :
	if _bgm_timer:
		_bgm_timer.stop()
	if _bgm_player:
		_bgm_player.stop()

func _play_next_bgm_note() :
	if not music_enabled or muted:
		return

	# 语音避让（Round 42）：语音台词播放期间 BGM 小节静默顺延——台词是
	# 主角，和声垫底让路，播完自动回归，不做音量打架。
	if _voice_player != null and _voice_player.playing:
		_bgm_timer.wait_time = 0.4
		_bgm_timer.start()
		return

	# 一个 tick 演奏一小节：低音持续整小节，和弦音四连琶音。
	var bars := []
	for section in SFX_CATALOG.MUSIC_SECTIONS:
		for bar in section["progression"]:
			bars.append(bar)
	var bar = bars[_bgm_step % bars.size()]
	var beat: float = SFX_CATALOG.MUSIC_BEAT

	var bass = _create_tone_player(float(bar["bass"]), beat * 4.0, SFX_CATALOG.MUSIC_BASS_DB)
	bass.play()

	for i in range(bar["tones"].size()):
		var tone = _create_tone_player(float(bar["tones"][i]), beat * 0.9, SFX_CATALOG.MUSIC_TONE_DB)
		tone.play()
		var stop_at = get_tree().create_timer(beat * 0.9 + 0.1)
		stop_at.connect("timeout", tone, "queue_free")

	# Schedule next bar
	_bgm_step += 1
	_bgm_timer.wait_time = beat * 4.0
	_bgm_timer.start()

func set_music_enabled(enabled: bool) :
	music_enabled = enabled
	if enabled and not muted:
		start_bgm()
	else:
		stop_bgm()
	save_settings()

# Volume control

func set_master_volume(volume: float) :
	master_volume = clamp(volume, 0.0, 1.0)
	save_settings()

func set_muted(is_muted: bool) :
	muted = is_muted
	save_settings()

func toggle_muted() -> bool:
	muted = not muted
	save_settings()
	return muted

func set_effects_enabled(enabled: bool) :
	effects_enabled = enabled
	save_settings()

func set_voice_enabled(enabled: bool) :
	voice_enabled = enabled
	save_settings()

func play_voice_path(path: String) :
	if muted or not voice_enabled:
		return
	if path == "":
		return
	var now = OS.get_ticks_msec()
	if path == _voice_last_path and now - _voice_last_ms < VOICE_REPEAT_GUARD_MS:
		return
	var stream = _load_voice_stream(path)
	if stream == null:
		return
	if "loop" in stream:
		stream.loop = false
	_voice_player.stop()
	_voice_player.stream = stream
	_voice_player.play()
	_voice_last_path = path
	_voice_last_ms = now

func _load_voice_stream(path: String):
	if _voice_cache.has(path):
		return _voice_cache[path]
	var stream = null
	# Preferred: the imported resource (game + CI after the import step).
	if ResourceLoader.exists(path):
		stream = load(path)
	# Fallback: feed raw ogg bytes (headless test env without imports).
	if stream == null:
		var file = File.new()
		if file.open(path, File.READ) == OK:
			var bytes = file.get_buffer(file.get_len())
			file.close()
			var ogg = AudioStreamOGGVorbis.new()
			if "data" in ogg:
				ogg.data = bytes
				stream = ogg
	_voice_cache[path] = stream
	return stream
