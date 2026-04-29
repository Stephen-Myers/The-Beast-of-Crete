extends CharacterBody2D
class_name GridPlayer

signal health_changed(current: int, maximum: int)
signal keys_changed(count: int)
signal score_changed(total: int)
signal torches_changed(count: int)

const MOVE_INITIAL_DELAY := 0.2 # seconds before repeat kicks in
const MOVE_REPEAT_INTERVAL := 0.1 # seconds between repeat steps
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

const SPRITE_RIGHT := preload("res://assets/player_right.png")
const SPRITE_DOWN := preload("res://assets/player_down.png")
const ANIM_INTERVAL := 0.15

var _anim_timer: float = 0.0
var _anim_frame: int = 0

@export var max_health: int = 3
## Min time between damage from bumping the same enemy while on the same tile (seconds).
@export var enemy_hit_cooldown_sec: float = 2.4

var health: int = 3

var keys_held: int = 0
var score: int = 0
var grid_cell: Vector2i = Vector2i.ZERO
var _held_dir: Vector2i = Vector2i.ZERO
var _move_timer: float = 0.0
var _initial_held: bool = false
var _enemy_hit_cd: float = 0.0
var _floor_advance_busy: bool = false
var _dead: bool = false
var maze: MazeController
var last_dir: Vector2i = Vector2i.ZERO
var _exit_unlocked: bool = false  # tracks whether door-open sound has played this floor
var _run_time: float = 0.0  # total elapsed seconds for game-over screen

var torches_held: int = 3


func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)
	keys_changed.emit(keys_held)
	score_changed.emit(score)
	torches_changed.emit(torches_held)
	maze = get_parent().get_node_or_null("Maze") as MazeController

	$Sprite2D.hframes = 4


func take_hit() -> bool:
	if _dead or health <= 0:
		return false
	health -= 1
	health_changed.emit(health, max_health)
	if health <= 0:
		_dead = true
		_held_dir = Vector2i.ZERO
		_show_game_over()
	else:
		AudioManager.play_take_damage()
	return health > 0


func _show_game_over() -> void:
	var floor_num := 1
	if maze != null:
		floor_num = maze.current_floor
	var overlay := GameOverOverlay.new()
	overlay.setup(score, floor_num, _run_time)
	get_tree().current_scene.add_child(overlay)


func initialize_grid(maze1: MazeController, cell: Vector2i) -> void:
	grid_cell = cell
	global_position = maze1.tile_to_world_center(grid_cell)
	_exit_unlocked = false  # reset on new floor


func reset_keys_for_new_floor() -> void:
	keys_held = 0
	keys_changed.emit(keys_held)

func reset_torches_for_new_floor() -> void:
	torches_held = 3
	torches_changed.emit(torches_held)

func place_torch() -> void:
	print("place torch (player)")
	if torches_held <= 0 or maze == null:
		return
	if last_dir == Vector2i.ZERO:
		return
	var behind: Vector2i = grid_cell - last_dir
	if not maze.is_walkable(behind):
		return
	if not maze.place_torch_at(behind):
		return
	AudioManager.play_torch_place()
	torches_held -= 1
	torches_changed.emit(torches_held)


func add_floor_completion_score(amount: int) -> void:
	if amount <= 0:
		return
	score += amount
	score_changed.emit(score)


func _unhandled_input(event: InputEvent) -> void:
	if _dead:
		return
	if not event is InputEventKey:
		return
	var e := event as InputEventKey
	if e.pressed and not e.echo and e.keycode == KEY_SPACE:
		place_torch()
		get_viewport().set_input_as_handled()
		return

	var d := _key_to_dir(e.keycode)
	if d == Vector2i.ZERO:
		return

	if e.pressed and not e.echo:
		# Fresh keydown: move immediately, then start repeat timer.
		_held_dir = d
		_initial_held = true
		_move_timer = MOVE_INITIAL_DELAY
		_try_move(d)
		get_viewport().set_input_as_handled()
	elif not e.pressed and _held_dir == d:
		# Key released: stop repeating.
		_held_dir = Vector2i.ZERO


func _process(delta: float) -> void:
	if _dead:
		return
	_run_time += delta
	_update_sprite(delta)
	_enemy_hit_cd = maxf(0.0, _enemy_hit_cd - delta)
	if maze != null and maze.has_enemy_at(grid_cell) && _enemy_hit_cd <= 0.0:
		take_hit()
		_enemy_hit_cd = enemy_hit_cooldown_sec
	if _held_dir == Vector2i.ZERO:
		return
	_move_timer -= delta
	if _move_timer <= 0.0:
		_try_move(_held_dir)
		_move_timer = MOVE_REPEAT_INTERVAL
		_initial_held = false


func _try_move(d: Vector2i) -> void:
	if _dead or maze == null or _floor_advance_busy:
		return
	var next: Vector2i = grid_cell + d
	# Questionable hack I added ------------------------------------
	# If you press an impossible movement, it assumes you meant
	# to continue in the last direction - For "turned too soon" situations
	# only works once!
	if not maze.is_walkable(next) and maze.is_walkable(grid_cell + last_dir + d):
		next = grid_cell + last_dir
	# End hack -----------------------------------------------------
	if not maze.is_walkable(next):
		return
	last_dir = d
	grid_cell = next
	global_position = maze.tile_to_world_center(grid_cell)
	if maze.try_collect_key_at(grid_cell):
		keys_held += 1
		keys_changed.emit(keys_held)
		AudioManager.play_key_pickup()
		# Play door-open sound when all keys collected
		if not _exit_unlocked and keys_held >= MazeController.KEYS_REQUIRED_FOR_EXIT:
			_exit_unlocked = true
			AudioManager.play_door_open()
	if maze.try_collect_heart_at(grid_cell, health, max_health):
		health += 1
		health_changed.emit(health, max_health)
		AudioManager.play_heart_pickup()
	# Update fog of war visibility
	if maze.fog:
		var viewers: Array = [grid_cell]
		for torch_cell in maze.get_torch_cells():
			viewers.append(torch_cell)
		maze.fog.update_visibility_multi(viewers, maze)
	if maze.should_advance_floor(grid_cell, keys_held):
		_floor_advance_busy = true
		AudioManager.play_level_complete()
		await maze.advance_to_next_floor(self)
		_floor_advance_busy = false

func _key_to_dir(keycode: Key) -> Vector2i:
	match keycode:
		KEY_RIGHT, KEY_D: return Vector2i(1, 0)
		KEY_LEFT, KEY_A: return Vector2i(-1, 0)
		KEY_DOWN, KEY_S: return Vector2i(0, 1)
		KEY_UP, KEY_W: return Vector2i(0, -1)
	return Vector2i.ZERO

func _update_sprite(delta: float) -> void:
	_anim_timer += delta
	if _anim_timer >= ANIM_INTERVAL:
		_anim_timer -= ANIM_INTERVAL
		_anim_frame = (_anim_frame + 1) % 4
		$Sprite2D.frame = _anim_frame

	if last_dir.x > 0: # Moving Right
		$Sprite2D.texture = SPRITE_RIGHT
		$Sprite2D.flip_h = false
	elif last_dir.x < 0: # Moving Left
		$Sprite2D.texture = SPRITE_RIGHT
		$Sprite2D.flip_h = true
	elif last_dir.y < 0: # Moving Up or Down
		$Sprite2D.texture = SPRITE_DOWN
		$Sprite2D.flip_h = false
	else:
		$Sprite2D.texture = SPRITE_DOWN
		$Sprite2D.flip_h = true
