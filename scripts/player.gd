extends CharacterBody2D
class_name GridPlayer

const MOVE_INITIAL_DELAY := 0.25 # seconds before repeat kicks in
const MOVE_REPEAT_INTERVAL := 0.1 # seconds between repeat steps

var _grid_cell: Vector2i = Vector2i.ZERO
var _held_dir: Vector2i = Vector2i.ZERO
var _move_timer: float = 0.0
var _initial_held: bool = false


func initialize_grid(maze: MazeController, cell: Vector2i) -> void:
	_grid_cell = cell
	global_position = maze.tile_to_world_center(_grid_cell)


func _unhandled_input(event: InputEvent) -> void:
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
	if _held_dir == Vector2i.ZERO:
		return
	_move_timer -= delta
	if _move_timer <= 0.0:
		_try_move(_held_dir)
		_move_timer = MOVE_REPEAT_INTERVAL
		_initial_held = false


func _try_move(d: Vector2i) -> void:
	var maze := get_parent().get_node_or_null("Maze") as MazeController
	if maze == null:
		return
	var next: Vector2i = _grid_cell + d
	if maze.is_walkable(next):
		_grid_cell = next
		global_position = maze.tile_to_world_center(_grid_cell)


func _key_to_dir(keycode: Key) -> Vector2i:
	match keycode:
		KEY_RIGHT, KEY_D: return Vector2i(1, 0)
		KEY_LEFT, KEY_A: return Vector2i(-1, 0)
		KEY_DOWN, KEY_S: return Vector2i(0, 1)
		KEY_UP, KEY_W: return Vector2i(0, -1)
	return Vector2i.ZERO