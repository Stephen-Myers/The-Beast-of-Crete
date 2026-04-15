extends CharacterBody2D
class_name Minotaur

@export var step_interval: float = 0.2

var _maze: MazeController
var _cell: Vector2i
var _target: Vector2i
var _step_timer: float = 0.0


func initialize(maze: MazeController, cell: Vector2i) -> void:
	_maze = maze
	_cell = cell
	global_position = _maze.tile_to_world_center(_cell)
	_maze.register_enemy_cell(_cell)
	_pick_new_target()


func _process(delta: float) -> void:
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = step_interval
		_take_step()


func _take_step() -> void:
	# If we've reached the target (or have none), pick a new one
	if _cell == _target:
		_pick_new_target()
		return

	var path := _bfs(_cell, _target)

	# BFS returned nothing — target is unreachable, pick a new one
	if path.is_empty():
		_pick_new_target()
		return

	# Take only the first step
	var next: Vector2i = path[0]
	_maze.unregister_enemy_cell(_cell)
	_cell = next
	_maze.register_enemy_cell(_cell)
	global_position = _maze.tile_to_world_center(_cell)


func _pick_new_target() -> void:
	var rows := _maze.enemy_grid_rows()
	var candidates: Array[Vector2i] = []
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			if _maze.is_walkable(Vector2i(x, y)):
				candidates.append(Vector2i(x, y))
	if candidates.is_empty():
		return
	# Keep re-rolling until we get something different from current cell
	var pick: Vector2i = _cell
	while pick == _cell and candidates.size() > 1:
		pick = candidates[randi() % candidates.size()]
	_target = pick


func _bfs(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if from == to:
		return []

	var visited: Dictionary = {from: true}
	var parent: Dictionary = {}
	var queue: Array[Vector2i] = [from]

	const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		for d in DIRS:
			var neighbor: Vector2i = current + d
			if visited.has(neighbor):
				continue
			if not _maze.is_walkable(neighbor):
				continue
			visited[neighbor] = true
			parent[neighbor] = current
			if neighbor == to:
				var path: Array[Vector2i] = []
				var step: Vector2i = to
				while step != from:
					path.append(step)
					step = parent[step]
				path.reverse()
				return path
			queue.append(neighbor)

	return []
