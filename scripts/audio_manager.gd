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

# ── Music players (persistent across scenes) ──────────────────
var _menu_music: AudioStreamPlayer
var _maze_ambience: AudioStreamPlayer
var _game_over_music: AudioStreamPlayer

# ── Spotted cooldown ──────────────────────────────────────────
var _spotted_cooldown: float = 0.0
## Minimum seconds between spotted sound plays
var spotted_cooldown_duration: float = 10.0

# ── Heartbeat proximity system ────────────────────────────────
## The audio file is a continuous heartbeat at ~61 BPM.
## We adjust pitch_scale to speed/slow the beats and volume to fade by distance.
var _heartbeat: AudioStreamPlayer
var _heartbeat_active: bool = false
## Distance in tiles at which heartbeat becomes audible
var heartbeat_range: float = 10.0
## pitch_scale when minotaur is at max range (normal speed)
var heartbeat_pitch_far: float = 1.0
## pitch_scale when minotaur is adjacent (fast heartbeat)
var heartbeat_pitch_close: float = 2.0


func _ready() -> void:
	_sfx_spotted = load("res://assets/audio/Spotted.wav")
	_sfx_take_damage = load("res://assets/audio/Take-Damage.wav")
	_sfx_level_complete = load("res://assets/audio/Level-Complete.wav")
	_sfx_menu_button = load("res://assets/audio/Menu-Button.wav")
	_sfx_door_open = load("res://assets/audio/Door-Open.wav")
	_sfx_key_pickup = load("res://assets/audio/Key-Pickup.wav")

	_menu_music = _make_player(load("res://assets/audio/Menu-Music.ogg"))
	_maze_ambience = _make_player(load("res://assets/audio/Maze-Ambience.ogg"))
	_game_over_music = _make_player(load("res://assets/audio/Game-Over.ogg"))
	_heartbeat = _make_player(load("res://assets/audio/Heartbeat.ogg"))


func _make_player(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	return p


func _process(delta: float) -> void:
	if _spotted_cooldown > 0.0:
		_spotted_cooldown -= delta


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
	_play_sfx(_sfx_spotted)

func play_take_damage() -> void:
	_play_sfx(_sfx_take_damage)

func play_level_complete() -> void:
	_play_sfx(_sfx_level_complete)

func play_menu_button() -> void:
	_play_sfx(_sfx_menu_button)

func play_door_open() -> void:
	_play_sfx(_sfx_door_open)

func play_key_pickup() -> void:
	_play_sfx(_sfx_key_pickup)


# ── Heartbeat proximity ──────────────────────────────────────

func update_heartbeat(tile_distance: float) -> void:
	if tile_distance > heartbeat_range:
		if _heartbeat_active:
			stop_heartbeat()
		return

	# 0.0 = adjacent, 1.0 = at max range
	var t := clampf(tile_distance / heartbeat_range, 0.0, 1.0)

	# Start playing if not already
	if not _heartbeat_active:
		_heartbeat_active = true
		_heartbeat.play()

	# Speed up when close, normal speed when far
	_heartbeat.pitch_scale = lerpf(heartbeat_pitch_close, heartbeat_pitch_far, t)
	# Louder when close, quieter when far
	_heartbeat.volume_db = lerpf(-5.0, -25.0, t)


func stop_heartbeat() -> void:
	_heartbeat_active = false
	_heartbeat.stop()
	_heartbeat.pitch_scale = 1.0