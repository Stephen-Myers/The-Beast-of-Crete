extends Node
## Autoload singleton — manages music, SFX, and the heartbeat proximity system.
## Add this as an autoload named "AudioManager" in Project → Project Settings → Autoload.

# ── Preloaded SFX streams ─────────────────────────────────────
var _sfx_spotted: AudioStream
var _sfx_take_damage: AudioStream
var _sfx_level_complete: AudioStream
var _sfx_menu_button: AudioStream
var _sfx_door_open: AudioStream
var _sfx_key_pickup: AudioStream
var _sfx_heart_pickup: AudioStream
var _sfx_torch_place: AudioStream

# ── Music players (persistent across scenes) ──────────────────
var _menu_music: AudioStreamPlayer
var _maze_ambience: AudioStreamPlayer
var _game_over_music: AudioStreamPlayer

# ── Spotted cooldown ──────────────────────────────────────────
var _spotted_cooldown: float = 0.0
## Minimum seconds between spotted sound plays
var spotted_cooldown_duration: float = 10.0

# ── Heartbeat proximity system ────────────────────────────────
## Single heartbeat sample replayed on a timer. Interval scales with distance, volume is constant.
var _heartbeat: AudioStreamPlayer
var _heartbeat_active: bool = false
var _heartbeat_timer: float = 0.0
## Distance in tiles at which heartbeat becomes audible
var heartbeat_range: float = 16.0
## Fastest beat interval in seconds (when minotaur is adjacent)
var heartbeat_min_interval: float = 0.3
## Slowest beat interval in seconds (when minotaur is at max range)
var heartbeat_max_interval: float = 2.0
var _heartbeat_interval: float = 1.0


func _ready() -> void:
	_sfx_spotted = load("res://assets/audio/Spotted.wav")
	_sfx_take_damage = load("res://assets/audio/Take-Damage.wav")
	_sfx_level_complete = load("res://assets/audio/Level-Complete.wav")
	_sfx_menu_button = load("res://assets/audio/Menu-Button.wav")
	_sfx_door_open = load("res://assets/audio/Door-Open.wav")
	_sfx_key_pickup = load("res://assets/audio/Key-Pickup.wav")
	_sfx_heart_pickup = load("res://assets/audio/Heart-Pickup.wav")
	_sfx_torch_place = load("res://assets/audio/Torch-Place.wav")

	_menu_music = _make_player(load("res://assets/audio/Menu-Music.ogg"))
	_maze_ambience = _make_player(load("res://assets/audio/Maze-Ambience.ogg"))
	_maze_ambience.volume_db = -6.0
	_game_over_music = _make_player(load("res://assets/audio/Game-Over.ogg"))
	_game_over_music.volume_db = -12.0
	_heartbeat = _make_player(load("res://assets/audio/Heartbeat.wav"))


func _make_player(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	return p


func _process(delta: float) -> void:
	if _spotted_cooldown > 0.0:
		_spotted_cooldown -= delta
	if _heartbeat_active:
		_heartbeat_timer -= delta
		if _heartbeat_timer <= 0.0 and not _heartbeat.playing:
			_heartbeat_timer = _heartbeat_interval
			_heartbeat.play()


# ── Music controls ────────────────────────────────────────────

func play_menu_music() -> void:
	_maze_ambience.stop()
	_game_over_music.stop()
	stop_heartbeat()
	if not _menu_music.playing:
		_menu_music.play()


func play_maze_ambience() -> void:
	_menu_music.stop()
	_game_over_music.stop()
	if not _maze_ambience.playing:
		_maze_ambience.play()


func play_game_over_music() -> void:
	_menu_music.stop()
	_maze_ambience.stop()
	stop_heartbeat()
	_game_over_music.play()


func stop_game_over_music() -> void:
	_game_over_music.stop()


func stop_all_music() -> void:
	_menu_music.stop()
	_maze_ambience.stop()
	_game_over_music.stop()
	stop_heartbeat()


# ── One-shot SFX ──────────────────────────────────────────────

func _play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func play_spotted() -> void:
	if _spotted_cooldown > 0.0:
		return
	_spotted_cooldown = spotted_cooldown_duration
	_play_sfx(_sfx_spotted, -18.0)

func play_take_damage() -> void:
	_play_sfx(_sfx_take_damage, -12.0)

func play_level_complete() -> void:
	_play_sfx(_sfx_level_complete)

func play_menu_button() -> void:
	_play_sfx(_sfx_menu_button)

func play_door_open() -> void:
	_play_sfx(_sfx_door_open)

func play_key_pickup() -> void:
	_play_sfx(_sfx_key_pickup, -6.0)

func play_heart_pickup() -> void:
	_play_sfx(_sfx_heart_pickup)

func play_torch_place() -> void:
	_play_sfx(_sfx_torch_place)


# ── Heartbeat proximity ──────────────────────────────────────

func update_heartbeat(tile_distance: float) -> void:
	if tile_distance > heartbeat_range:
		if _heartbeat_active:
			stop_heartbeat()
		return

	# 0.0 = adjacent, 1.0 = at max range
	var t := clampf((tile_distance - 2.0) / (heartbeat_range - 2.0), 0.0, 1.0)
	_heartbeat_interval = lerpf(heartbeat_min_interval, heartbeat_max_interval, t)

	if not _heartbeat_active:
		_heartbeat_active = true
		_heartbeat_timer = 0.0  # beat immediately on first enter


func stop_heartbeat() -> void:
	_heartbeat_active = false
	_heartbeat.stop()