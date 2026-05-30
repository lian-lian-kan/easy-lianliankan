extends Node

# Audio players dictionary
var _players: Dictionary = {}

# Audio settings
var master_volume: float = 0.7
var effects_enabled: bool = true
var music_enabled: bool = true
var muted: bool = false

# Sound effect streams (using procedural audio or simple beeps for web compatibility)
var _sounds: Dictionary = {}

# Background music player
var _bgm_player: AudioStreamPlayer = null
var _bgm_timer: Timer = null
var _current_note_index: int = 0

# BGM melody (simple cheerful tune)
const BGM_MELODY = [
	{"note": 523.25, "duration": 0.25},  # C5
	{"note": 659.25, "duration": 0.25},  # E5
	{"note": 783.99, "duration": 0.25},  # G5
	{"note": 1046.50, "duration": 0.25}, # C6
	{"note": 783.99, "duration": 0.25},  # G5
	{"note": 659.25, "duration": 0.25},  # E5
	{"note": 523.25, "duration": 0.5},   # C5
	{"note": 587.33, "duration": 0.25},  # D5
	{"note": 698.46, "duration": 0.25},  # F5
	{"note": 880.00, "duration": 0.25},  # A5
	{"note": 1174.66, "duration": 0.25}, # D6
	{"note": 880.00, "duration": 0.25},  # A5
	{"note": 698.46, "duration": 0.25},  # F5
	{"note": 587.33, "duration": 0.5},   # D5
]

func _ready() :
	_load_settings()
	_initialize_sounds()
	_bgm_timer = Timer.new()
	_bgm_timer.one_shot = true
	_bgm_timer.connect("timeout", self, "_play_next_bgm_note")
	add_child(_bgm_timer)

func _load_settings() :
	# Try to load from config file
	var config = ConfigFile.new()
	var err = config.load("user://audio_settings.cfg")
	if err == OK:
		master_volume = config.get_value("audio", "master_volume", 0.7)
		effects_enabled = config.get_value("audio", "effects_enabled", true)
		music_enabled = config.get_value("audio", "music_enabled", true)
		muted = config.get_value("audio", "muted", false)

func save_settings() :
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "effects_enabled", effects_enabled)
	config.set_value("audio", "music_enabled", music_enabled)
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
	for i in range(frame_count):
		var sample_value: int = int(round(sin(phase) * 32767.0 * amplitude))
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

# Public API for playing sound effects

func play_select() :
	# High pitched short beep for selection
	_play_tone(880.0, 0.08, -12.0)

func play_eliminate() :
	# Pleasant chord for successful match
	_play_tone(523.25, 0.1, -10.0)  # C5
	yield(get_tree().create_timer(0.05), "timeout")
	_play_tone(659.25, 0.1, -10.0)  # E5

func play_eliminate_combo(combo: int) :
	# Play different sounds based on combo level
	if combo >= 10:
		# 10+ combo: High pitch arpeggio
		_play_tone(1046.50, 0.08, -8.0)  # C6
		yield(get_tree().create_timer(0.03), "timeout")
		_play_tone(1318.51, 0.08, -8.0)  # E6
		yield(get_tree().create_timer(0.03), "timeout")
		_play_tone(1567.98, 0.08, -8.0)  # G6
		yield(get_tree().create_timer(0.03), "timeout")
		_play_tone(2093.00, 0.12, -6.0)  # C7
	elif combo >= 7:
		# 7+ combo: Higher pitch chord
		_play_tone(783.99, 0.1, -9.0)  # G5
		yield(get_tree().create_timer(0.04), "timeout")
		_play_tone(987.77, 0.1, -9.0)  # B5
		yield(get_tree().create_timer(0.04), "timeout")
		_play_tone(1174.66, 0.1, -9.0)  # D6
	elif combo >= 5:
		# 5+ combo: Medium-high pitch
		_play_tone(659.25, 0.1, -10.0)  # E5
		yield(get_tree().create_timer(0.04), "timeout")
		_play_tone(830.61, 0.1, -10.0)  # G#5
		yield(get_tree().create_timer(0.04), "timeout")
		_play_tone(987.77, 0.1, -10.0)  # B5
	elif combo >= 3:
		# 3+ combo: Slightly higher pitch
		_play_tone(587.33, 0.1, -10.0)  # D5
		yield(get_tree().create_timer(0.05), "timeout")
		_play_tone(739.99, 0.1, -10.0)  # F#5
	else:
		# Base combo: Standard
		play_eliminate()

func play_error() :
	# Low dissonant tone for error
	_play_tone(200.0, 0.15, -8.0)

func play_hint() :
	# Gentle rising tone for hint
	_play_tone(440.0, 0.08, -14.0)
	yield(get_tree().create_timer(0.05), "timeout")
	_play_tone(554.0, 0.08, -14.0)
	yield(get_tree().create_timer(0.05), "timeout")
	_play_tone(659.0, 0.08, -14.0)

func play_win() :
	# Victory fanfare
	_play_tone(523.25, 0.15, -8.0)  # C5
	yield(get_tree().create_timer(0.1), "timeout")
	_play_tone(659.25, 0.15, -8.0)  # E5
	yield(get_tree().create_timer(0.1), "timeout")
	_play_tone(783.99, 0.15, -8.0)  # G5
	yield(get_tree().create_timer(0.1), "timeout")
	_play_tone(1046.50, 0.3, -6.0)  # C6

func play_button_click() :
	# Subtle click sound
	_play_tone(600.0, 0.05, -15.0)

func play_shuffle() :
	# Shuffling sound effect
	for i in range(5):
		_play_tone(300.0 + i * 50.0, 0.05, -12.0)
		yield(get_tree().create_timer(0.05), "timeout")

func play_combo(combo_level: int) :
	# Rising pitch based on combo level
	var base_freq = 440.0
	var freq = base_freq + (combo_level * 50.0)
	_play_tone(freq, 0.1, -10.0)
	yield(get_tree().create_timer(0.05), "timeout")
	_play_tone(freq * 1.25, 0.15, -8.0)

func play_time_warning() :
	# Urgent ticking sound
	_play_tone(800.0, 0.1, -10.0)

func play_fail() :
	# Sad descending tone for failure
	_play_tone(349.23, 0.2, -8.0)  # F4
	yield(get_tree().create_timer(0.15), "timeout")
	_play_tone(293.66, 0.2, -8.0)  # D4
	yield(get_tree().create_timer(0.15), "timeout")
	_play_tone(246.94, 0.3, -6.0)  # B3

# Background Music

func start_bgm() :
	if not music_enabled or muted:
		return
	_current_note_index = 0
	_play_next_bgm_note()

func stop_bgm() :
	if _bgm_timer:
		_bgm_timer.stop()
	if _bgm_player:
		_bgm_player.stop()

func _play_next_bgm_note() :
	if not music_enabled or muted:
		return

	var note_data = BGM_MELODY[_current_note_index]
	var freq = note_data.note
	var duration = note_data.duration

	# Play note quietly for background
	var player = _create_tone_player(freq, duration, -22.0)
	player.play()

	# Schedule next note
	_current_note_index = (_current_note_index + 1) % BGM_MELODY.size()
	_bgm_timer.wait_time = duration
	_bgm_timer.start()

	# Auto-cleanup
	yield(get_tree().create_timer(duration + 0.1), "timeout")
	player.queue_free()

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
