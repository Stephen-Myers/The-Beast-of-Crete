extends CharacterBody2D
class_name GridPlayer

var _grid_cell: Vector2i = Vector2i.ZERO


func initialize_grid(maze: MazeController, cell: Vector2i) -> void:
	_grid_cell = cell
	global_position = maze.tile_to_world_center(_grid_cell)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var e := event as InputEventKey
	if not e.pressed or e.echo:
		return

	var maze := get_parent().get_node_or_null("Maze") as MazeController
	if maze == null:
		return

	var d := Vector2i.ZERO
	match e.keycode:
		KEY_RIGHT, KEY_D:
			d = Vector2i(1, 0)
		KEY_LEFT, KEY_A:
			d = Vector2i(-1, 0)
		KEY_DOWN, KEY_S:
			d = Vector2i(0, 1)
		KEY_UP, KEY_W:
			d = Vector2i(0, -1)
	if d == Vector2i.ZERO:
		return

	var next: Vector2i = _grid_cell + d
	if maze.is_walkable(next):
		_grid_cell = next
		global_position = maze.tile_to_world_center(_grid_cell)
		get_viewport().set_input_as_handled()
