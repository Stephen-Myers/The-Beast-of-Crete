extends CharacterBody2D
class_name GridPlayer

signal health_changed(current: int, maximum: int)

const MOVE_INITIAL_DELAY := 0.2 # seconds before repeat kicks in
const MOVE_REPEAT_INTERVAL := 0.1 # seconds between repeat steps
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

@export var max_health: int = 3
## Min time between damage from bumping the same enemy while holding a key (seconds).
@export var enemy_hit_cooldown_sec: float = 1

var health: int = 3

var keys_held: int = 0
var grid_cell: Vector2i = Vector2i.ZERO
var _held_dir: Vector2i = Vector2i.ZERO
var _move_timer: float = 0.0
var _initial_held: bool = false
var _enemy_hit_cd: float = 0.0
var _floor_advance_busy: bool = false
var _dead: bool = false
var maze: MazeController
var last_dir: Vector2i = Vector2i.ZERO


func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)
	maze = get_parent().get_node_or_null("Maze") as MazeController


func take_hit() -> bool:
	if _dead or health <= 0:
		return false
	health -= 1
	health_changed.emit(health, max_health)
	if health <= 0:
		_dead = true
		_held_dir = Vector2i.ZERO
		get_tree().call_deferred("change_scene_to_file", MAIN_MENU_SCENE)
	return health > 0


func initialize_grid(maze1: MazeController, cell: Vector2i) -> void:
	grid_cell = cell
	global_position = maze1.tile_to_world_center(grid_cell)


func _unhandled_input(event: InputEvent) -> void:
	if _dead:
		return
	if not event is InputEventKey:
		return
	var e := event as InputEventKey

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
	if not maze.is_walkable(next):
		return
	last_dir = d
	grid_cell = next
	global_position = maze.tile_to_world_center(grid_cell)
	if maze.try_collect_key_at(grid_cell):
		keys_held += 1
	if maze.should_advance_floor(grid_cell, keys_held):
		_floor_advance_busy = true
		await maze.advance_to_next_floor(self )
		_floor_advance_busy = false

func _key_to_dir(keycode: Key) -> Vector2i:
	match keycode:
		KEY_RIGHT, KEY_D: return Vector2i(1, 0)
		KEY_LEFT, KEY_A: return Vector2i(-1, 0)
		KEY_DOWN, KEY_S: return Vector2i(0, 1)
		KEY_UP, KEY_W: return Vector2i(0, -1)
	return Vector2i.ZERO
