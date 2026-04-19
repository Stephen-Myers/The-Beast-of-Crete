extends CharacterBody2D
class_name Minotaur

@export var step_interval: float = .2
@export_range(0.0, 1.0) var wander_random_chance: float = 0.5
@export var hunt_hiding_places_to_check: int = 2
@export var get_away_time := 0.5


enum State {WANDER, CHASE, HUNT}
var _state: State = State.WANDER

var _player: GridPlayer
var _hunt_hiding_places: Array[Vector2i] = []
var _hunt_snapshot_pos: Vector2i = Vector2i.ZERO
var _hunt_snapshot_dir: Vector2i = Vector2i.ZERO
var _hunt_tries: int = 0

var _maze: MazeController
var _cell: Vector2i
var _target: Vector2i
var _step_timer: float = 0.0
var _get_away_timer: float = 0.0


func initialize(maze: MazeController, cell: Vector2i, player: GridPlayer) -> void:
	print("Minotaur: Initialized at cell ", cell)
	_maze = maze
	_cell = cell
	_player = player
	global_position = _maze.tile_to_world_center(_cell)
	_maze.register_enemy_cell(_cell)
	_pick_new_target()


func _process(delta: float) -> void:
	_step_timer -= delta
	if _player.grid_cell == _cell:
		print("Minotaur: Player caught at ", _cell, "! Dealing damage.")
		_get_away_timer = get_away_time
		return
	if _get_away_timer > 0.0:
		_get_away_timer -= delta
		return

	if _step_timer <= 0.0:
		_step_timer = step_interval
		_take_step()


func _take_step() -> void:
	match _state:
		State.WANDER:
			if _has_line_of_sight():
				print("Minotaur: Spotted player! WANDER -> CHASE")
				_state = State.CHASE
				return _take_step()
			if _cell == _target:
				print("Minotaur: Reached wander target at ", _cell, ". Picking new target.")
				_pick_new_target()
				return
			var path := _bfs(_cell, _target)
			if path.is_empty():
				print("Minotaur: Path to target blocked or invalid. Picking new target.")
				_pick_new_target()
				return
			var next: Vector2i = path[0]
			_maze.unregister_enemy_cell(_cell)
			_cell = next
			_maze.register_enemy_cell(_cell)
			global_position = _maze.tile_to_world_center(_cell)

		State.CHASE:
			if not _has_line_of_sight():
				print("Minotaur: Lost line of sight! CHASE -> HUNT")
				_enter_hunt_state()
				_state = State.HUNT
				return _take_step()
			_chase_step()

		State.HUNT:
			if _has_line_of_sight():
				print("Minotaur: Spotted player while hunting! HUNT -> CHASE")
				_state = State.CHASE
				return _take_step()
			_hunt_step()


func _has_line_of_sight() -> bool:
	var m := _cell
	var p := _player.grid_cell

	# Must share a row or column
	if m.x != p.x and m.y != p.y:
		return false

	# Determine step direction
	var step: Vector2i
	if m.x == p.x:
		step = Vector2i(0, 1) if p.y > m.y else Vector2i(0, -1)
	else:
		step = Vector2i(1, 0) if p.x > m.x else Vector2i(-1, 0)

	# Walk from minotaur toward player, checking for walls
	var current := m + step
	while current != p:
		if not _maze.is_walkable(current):
			return false
		current += step

	return true


func _pick_new_target() -> void:
	if randf() < wander_random_chance:
		_pick_random_target()
	else:
		_pick_target_near_player()


func _pick_random_target() -> void:
	var rows := _maze.enemy_grid_rows()
	var candidates: Array[Vector2i] = []
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			var cell := Vector2i(x, y)
			if _maze.is_walkable(cell) and cell != _cell:
				candidates.append(cell)
	if candidates.is_empty():
		return
	_target = candidates[randi() % candidates.size()]
	print("Minotaur: Wandering to random location: ", _target)


func _pick_target_near_player() -> void:
	var candidates: Array[Vector2i] = []
	var p := _player.grid_cell
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var cell := Vector2i(p.x + dx, p.y + dy)
			if _maze.is_walkable(cell) and cell != _cell:
				candidates.append(cell)
	if candidates.is_empty():
		_pick_random_target()
		return
	_target = candidates[randi() % candidates.size()]
	print("Minotaur: Wandering to area near player: ", _target)


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


func _chase_step() -> void:
	var path := _bfs(_cell, _player.grid_cell)
	if path.is_empty():
		return
	var next: Vector2i = path[0]
	_maze.unregister_enemy_cell(_cell)
	_cell = next
	_maze.register_enemy_cell(_cell)
	global_position = _maze.tile_to_world_center(_cell)


func _calculate_hiding_places() -> void:
	_hunt_hiding_places.clear()
	var found: Dictionary = {}
	var start := _hunt_snapshot_pos + _hunt_snapshot_dir
	print("Minotaur: Calculating hiding places starting from: ", start)
	if _maze.is_walkable(start):
		_dfs(start, 7, _hunt_snapshot_pos, found)
	print("Minotaur: Found ", _hunt_hiding_places.size(), " potential hiding places.")
	for place in _hunt_hiding_places:
		print("  ", place)


func _dfs(cell: Vector2i, steps_left: int, came_from: Vector2i, found: Dictionary) -> void:
	if found.has(cell):
		return
	found[cell] = true
	if steps_left == 0:
		_hunt_hiding_places.append(cell)
		return
	var open_dirs := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbor: Vector2i = cell + d
		if neighbor == came_from:
			continue
		if not _maze.is_walkable(neighbor):
			continue
		_dfs(neighbor, steps_left - 1, cell, found)
		open_dirs += 1
	if open_dirs <= 0:
		_hunt_hiding_places.append(cell)


func _enter_hunt_state() -> void:
	_hunt_tries = 2
	_hunt_snapshot_pos = _player.grid_cell
	_hunt_snapshot_dir = _player.last_dir
	print("Minotaur: Player last seen at ", _hunt_snapshot_pos, " moving in direction ", _hunt_snapshot_dir)
	_calculate_hiding_places()
	_assign_next_hunt_target()


func _assign_next_hunt_target() -> void:
	if _hunt_hiding_places.is_empty():
		print("Minotaur: No hiding places left to check. Returning to WANDER.")
		_state = State.WANDER
		_pick_new_target()
		return
	# Pick a random hiding place from the list and remove it
	var idx := randi() % _hunt_hiding_places.size()
	_target = _hunt_hiding_places[idx]
	_hunt_hiding_places.remove_at(idx)
	print("Minotaur: Investigating hiding place at ", _target)


func _hunt_step() -> void:
	if _cell == _target:
		_hunt_tries -= 1

		print("Minotaur: Reached and cleared hiding place at ", _cell)
		# Checked this location, assign the next one
		# But first check if we've used our allowed number of locations
		if _hunt_tries <= 0 or _hunt_hiding_places.is_empty():
			print("Minotaur: Checked enough hiding places. Giving up hunt. HUNT -> WANDER")
			_state = State.WANDER
			_pick_new_target()
			return
		_assign_next_hunt_target()
		return
	var path := _bfs(_cell, _target)
	if path.is_empty():
		print("Minotaur: Cannot reach hiding place at ", _target, ". Picking another.")
		_assign_next_hunt_target()
		return
	var next: Vector2i = path[0]
	_maze.unregister_enemy_cell(_cell)
	_cell = next
	_maze.register_enemy_cell(_cell)
	global_position = _maze.tile_to_world_center(_cell)
