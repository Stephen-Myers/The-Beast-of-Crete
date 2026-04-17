extends Node2D
class_name MazeController

const TILE_SIZE := 8
const COLOR_FLOOR := Color(1, 1, 1)

# ── Maze generation settings ──────────────────────────────────
## Width of each quadrant in cells (total maze width = 2 * this)
@export var quadrant_width: int = 6
## Height of each quadrant in cells (total maze height = 2 * this)
@export var quadrant_height: int = 6
## Optional sprite for key pickups; if unset, a gold placeholder block is drawn.
@export var key_icon: Texture2D
## Turn off placeholder enemy when minotaur is in the scene; then delete scripts/placeholder_enemy_maze.gd.
@export var use_placeholder_enemy: bool = true
## Chance to remove each dead end (0.0 = pure maze, 1.0 = no dead ends)
@export_range(0.0, 1.0) var braid_chance: float = 0.5

# ── Direction bitflags for the cell grid ──────────────────────
const _N := 1
const _E := 2
const _S := 4
const _W := 8
const _OPPOSITE := { 1: 4, 4: 1, 2: 8, 8: 2 }  # N<->S, E<->W
const _DX := { 1: 0, 2: 1, 4: 0, 8: -1 }
const _DY := { 1: -1, 2: 0, 4: 1, 8: 0 }
const _DIRS := [1, 2, 4, 8]

# ── State ─────────────────────────────────────────────────────
var _rows: PackedStringArray = []
var _wall_texture: Texture2D = null
var spawn_cell: Vector2i = Vector2i.ZERO
var exit_cell: Vector2i = Vector2i.ZERO
var _keys_by_cell: Dictionary = {}
var _enemy_cells: Dictionary = {}
var fog: FogOfWar = null


func _ready() -> void:
	_wall_texture = load("res://assets/under_walls.png")

	# Generate the maze and store it as _rows (same format as the old hardcoded layout)
	_rows = _generate_maze_rows()

	# Find spawn (P) and exit (E) markers
	for y in range(_rows.size()):
		var row: String = _rows[y]
		for x in range(row.length()):
			if row[x] == "P":
				spawn_cell = Vector2i(x, y)
			elif row[x] == "E":
				exit_cell = Vector2i(x, y)

	# Build the visual scene
	var floors := Node2D.new()
	floors.name = "Floors"
	floors.z_index = 0
	add_child(floors)

	var walls := Node2D.new()
	walls.name = "Walls"
	walls.z_index = 1
	add_child(walls)

	var keys_root := Node2D.new()
	keys_root.name = "Keys"
	keys_root.z_index = 2
	add_child(keys_root)

	var enemies_root := Node2D.new()
	enemies_root.name = "Enemies"
	enemies_root.z_index = 2
	add_child(enemies_root)

	if use_placeholder_enemy:
		PlaceholderEnemyMaze.spawn(self, enemies_root)

	for y in range(_rows.size()):
		var row: String = _rows[y]
		for x in range(row.length()):
			var center := Vector2(x + 0.5, y + 0.5) * TILE_SIZE
			if row[x] == "#":
				_add_wall_block(walls, center, Vector2i(x, y))
			else:
				_add_floor_tile(floors, center)
				if row[x] == "K":
					var kp := KeyPickup.new()
					kp.setup(Vector2i(x, y), center, TILE_SIZE, key_icon)
					keys_root.add_child(kp)
					_keys_by_cell[Vector2i(x, y)] = kp

	# Initialize fog of war
	fog = FogOfWar.new()
	fog.name = "Fog"
	fog.z_index = 10 # render above everything else
	add_child(fog)
	fog.setup(_rows, TILE_SIZE)

	# Initialize player
	var player := get_node_or_null("../Player")
	if player and player.has_method("initialize_grid"):
		player.initialize_grid(self, spawn_cell)
	if fog:
		fog.update_visibility(spawn_cell, self)

	# Fit camera
	var cam := get_node_or_null("../Camera2D") as Camera2D
	if cam and _rows.size() > 0:
		var w := _rows[0].length()
		var h := _rows.size()
		var hud_px := 8.0
		cam.global_position = Vector2(w, h) * TILE_SIZE / 2.0
		cam.make_current()
		await get_tree().process_frame
		var maze_size := Vector2(w * TILE_SIZE, h * TILE_SIZE)
		var vp := get_viewport().get_visible_rect().size
		if vp.x > 0.0 and vp.y > 0.0:
			var game_area := Vector2(vp.x, vp.y - hud_px)
			var z: float = minf(game_area.x / maze_size.x, game_area.y / maze_size.y) * 0.92
			cam.zoom = Vector2(z, z)
			cam.offset = Vector2(0, -hud_px / 2.0)


# PROCEDURAL MAZE GENERATION

## Generates the full maze and returns it as a PackedStringArray
## in the same '#' / '.' / 'P' / 'E' format the renderer expects.
func _generate_maze_rows() -> PackedStringArray:
	var qw := quadrant_width
	var qh := quadrant_height
	var full_cw := qw * 2  # total cell width
	var full_ch := qh * 2  # total cell height

	# Generate 4 quadrant mazes independently
	var q_tl := _gen_quadrant(qw, qh)
	var q_tr := _gen_quadrant(qw, qh)
	var q_bl := _gen_quadrant(qw, qh)
	var q_br := _gen_quadrant(qw, qh)

	# Combine into one cell grid
	var cells := _combine(q_tl, q_tr, q_bl, q_br, qw, qh)

	# Connect quadrants in a loop
	_connect_loop(cells, qw, qh)

	# Braid: remove dead ends to create alternate escape routes
	_braid(cells, full_cw, full_ch)

	# Convert cell grid to tile characters
	var tw := full_cw * 2 + 1
	var th := full_ch * 2 + 1
	var grid: Array[String] = []
	for _y in range(th):
		grid.append("#".repeat(tw))

	# Carve floors into the character grid
	for cy in range(full_ch):
		for cx in range(full_cw):
			var val: int = cells[cy][cx]
			var tx := cx * 2 + 1
			var ty := cy * 2 + 1

			# Cell center is always floor
			grid[ty] = _set_char(grid[ty], tx, ".")

			# If east wall open, carve passage to the right
			if val & _E:
				grid[ty] = _set_char(grid[ty], tx + 1, ".")

			# If south wall open, carve passage below
			if val & _S:
				grid[ty + 1] = _set_char(grid[ty + 1], tx, ".")

	# Place entrance (P) on the bottom edge
	var entrance_x := _find_border_opening(grid, th - 2, tw)
	grid[th - 2] = _set_char(grid[th - 2], entrance_x, "P")
	grid[th - 1] = _set_char(grid[th - 1], entrance_x, ".")  # open outer wall

	# Place exit (E) on the top edge
	var exit_x := _find_border_opening(grid, 1, tw)
	grid[1] = _set_char(grid[1], exit_x, "E")
	grid[0] = _set_char(grid[0], exit_x, ".")  # open outer wall

	_place_keys_in_grid(grid, tw, th)

	var result: PackedStringArray = []
	for row in grid:
		result.append(row)
	return result


## Places exactly three key markers ('K') on walkable cells (deterministic from sorted floors).
func _place_keys_in_grid(grid: Array[String], tw: int, th: int) -> void:
	var floors: Array[Vector2i] = []
	for y in range(1, th - 1):
		for x in range(1, tw - 1):
			if grid[y][x] == ".":
				floors.append(Vector2i(x, y))
	var n := floors.size()
	if n < 3:
		return
	floors.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	var picks: Array[Vector2i] = [floors[n / 4], floors[n / 2], floors[(n * 3) / 4]]
	var placed: Dictionary = {}
	for p: Vector2i in picks:
		if placed.has(p):
			continue
		placed[p] = true
		grid[p.y] = _set_char(grid[p.y], p.x, "K")


## Finds a random floor tile on a given row to use as an entrance/exit.
func _find_border_opening(grid: Array[String], row_idx: int, width: int) -> int:
	var candidates: Array[int] = []
	for x in range(1, width - 1):
		if grid[row_idx][x] == ".":
			candidates.append(x)
	return candidates[randi() % candidates.size()]


## Helper: GDScript strings are immutable, so we rebuild with one char replaced.
func _set_char(s: String, idx: int, c: String) -> String:
	return s.substr(0, idx) + c + s.substr(idx + 1)


# RECURSIVE BACKTRACKING ALGORITHM

## Generates a single quadrant maze. Returns 2D array of ints (bitflags
## indicating which walls have been removed).
func _gen_quadrant(w: int, h: int) -> Array:
	var grid := []
	for y in range(h):
		var row := []
		for x in range(w):
			row.append(0)
		grid.append(row)

	var visited := {}
	var stack := []
	var start := Vector2i(randi() % w, randi() % h)
	visited[start] = true
	stack.append(start)

	while stack.size() > 0:
		var current: Vector2i = stack[-1]
		var neighbors := _unvisited_neighbors(current, w, h, visited)

		if neighbors.size() > 0:
			var pick: Array = neighbors[randi() % neighbors.size()]
			var next_cell: Vector2i = pick[0]
			var dir: int = pick[1]

			grid[current.y][current.x] |= dir
			grid[next_cell.y][next_cell.x] |= _OPPOSITE[dir]

			visited[next_cell] = true
			stack.append(next_cell)
		else:
			stack.pop_back()

	return grid


func _unvisited_neighbors(cell: Vector2i, w: int, h: int, visited: Dictionary) -> Array:
	var result := []
	for dir in _DIRS:
		var nx := cell.x + int(_DX[dir])
		var ny := cell.y + int(_DY[dir])
		var nv := Vector2i(nx, ny)
		if nx >= 0 and nx < w and ny >= 0 and ny < h and not visited.has(nv):
			result.append([nv, dir])
	return result


# QUADRANT COMBINING AND LOOP CONNECTION

func _combine(tl: Array, top_right: Array, bl: Array, br: Array, qw: int, qh: int) -> Array:
	var full_w := qw * 2
	var full_h := qh * 2
	var grid := []
	for y in range(full_h):
		var row := []
		for x in range(full_w):
			if x < qw and y < qh:
				row.append(tl[y][x])
			elif x >= qw and y < qh:
				row.append(top_right[y][x - qw])
			elif x < qw and y >= qh:
				row.append(bl[y - qh][x])
			else:
				row.append(br[y - qh][x - qw])
		grid.append(row)
	return grid


## Opens 4 passages between quadrants to create the loop.
## TL <-> TR (top), TR <-> BR (right), BR <-> BL (bottom), BL <-> TL (left)
func _connect_loop(grid: Array, qw: int, qh: int) -> void:
	# TL <-> TR: vertical center line, random row in top half
	var row_top := randi() % qh
	grid[row_top][qw - 1] |= _E
	grid[row_top][qw] |= _W

	# BL <-> BR: vertical center line, random row in bottom half
	var row_bot := qh + (randi() % qh)
	grid[row_bot][qw - 1] |= _E
	grid[row_bot][qw] |= _W

	# TL <-> BL: horizontal center line, random col in left half
	var col_left := randi() % qw
	grid[qh - 1][col_left] |= _S
	grid[qh][col_left] |= _N

	# TR <-> BR: horizontal center line, random col in right half
	var col_right := qw + (randi() % qw)
	grid[qh - 1][col_right] |= _S
	grid[qh][col_right] |= _N

## Removes dead ends by opening a random wall, creating alternate paths.
func _braid(cells: Array, w: int, h: int) -> void:
	for y in range(h):
		for x in range(w):
			var val: int = cells[y][x]
			# Count open walls — dead end has exactly 1
			var open := 0
			for dir in _DIRS:
				if val & dir:
					open += 1
			if open != 1:
				continue
			if randf() > braid_chance:
				continue
			# Find closed walls that lead to a valid neighbor
			var closed: Array[int] = []
			for dir in _DIRS:
				if val & dir:
					continue
				var nx := x + int(_DX[dir])
				var ny := y + int(_DY[dir])
				if nx >= 0 and nx < w and ny >= 0 and ny < h:
					closed.append(dir)
			if closed.is_empty():
				continue
			# Open a random closed wall
			var dir: int = closed[randi() % closed.size()]
			var nx := x + int(_DX[dir])
			var ny := y + int(_DY[dir])
			cells[y][x] |= dir
			cells[ny][nx] |= int(_OPPOSITE[dir])


# RENDERING

func _add_floor_tile(parent: Node2D, center: Vector2) -> void:
	var poly := Polygon2D.new()
	poly.color = COLOR_FLOOR
	var h := TILE_SIZE
	poly.polygon = PackedVector2Array(
		[Vector2(-h, -h + 6), Vector2(h, -h + 6), Vector2(h, h - 2), Vector2(-h, h - 2)]
	)
	poly.position = center
	parent.add_child(poly)


func _get_wall_frame(tile: Vector2i) -> int:
	var mask := 0
	if _is_wall(tile + Vector2i(0, -1)): mask |= 0b1000 # N
	if _is_wall(tile + Vector2i(1, 0)): mask |= 0b0100 # E
	if _is_wall(tile + Vector2i(0, 1)): mask |= 0b0010 # S
	if _is_wall(tile + Vector2i(-1, 0)): mask |= 0b0001 # W
	return mask


func _is_wall(tile: Vector2i) -> bool:
	if tile.y < 0 or tile.y >= _rows.size():
		return false
	var row: String = _rows[tile.y]
	if tile.x < 0 or tile.x >= row.length():
		return false
	return row[tile.x] == "#"


func _add_wall_block(parent: Node2D, center: Vector2, tile: Vector2i) -> void:
	var body := StaticBody2D.new()
	body.position = center

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	shape.shape = rect
	body.add_child(shape)

	var frame_index := _get_wall_frame(tile)
	var atlas := AtlasTexture.new()
	atlas.atlas = _wall_texture
	atlas.region = Rect2(frame_index * TILE_SIZE, 0, TILE_SIZE, 12)
	atlas.filter_clip = true

	var sprite := Sprite2D.new()
	sprite.texture = atlas
	body.add_child(sprite)

	parent.add_child(body)


func _fit_camera_to_maze(cam: Camera2D, grid_w: int, grid_h: int) -> void:
	var maze_size := Vector2(grid_w * TILE_SIZE, grid_h * TILE_SIZE)
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0 or maze_size.x <= 0.0 or maze_size.y <= 0.0:
		return
	var z: float = minf(vp.x / maze_size.x, vp.y / maze_size.y) * 0.92
	cam.zoom = Vector2(z, z)


func tile_to_world_center(tile: Vector2i) -> Vector2:
	return (Vector2(tile) + Vector2(0.5, 0.5)) * TILE_SIZE


func is_walkable(tile: Vector2i) -> bool:
	if tile.y < 0 or tile.y >= _rows.size():
		return false
	var row: String = _rows[tile.y]
	if tile.x < 0 or tile.x >= row.length():
		return false
	return row[tile.x] != "#"


func has_enemy_at(tile: Vector2i) -> bool:
	return _enemy_cells.has(tile)


## Call when an enemy occupies a grid cell (hazard / bump damage). Real enemy AI uses this too.
func register_enemy_cell(cell: Vector2i) -> void:
	_enemy_cells[cell] = true


func unregister_enemy_cell(cell: Vector2i) -> void:
	_enemy_cells.erase(cell)


## Row strings for hazard placement scripts (same as maze layout: # wall, . floor, K key, …).
func enemy_grid_rows() -> PackedStringArray:
	return _rows


func try_collect_key_at(tile: Vector2i) -> bool:
	if not _keys_by_cell.has(tile):
		return false
	var kp: Node = _keys_by_cell[tile]
	_keys_by_cell.erase(tile)
	if is_instance_valid(kp):
		kp.queue_free()
	if tile.y >= 0 and tile.y < _rows.size():
		var row: String = _rows[tile.y]
		if tile.x >= 0 and tile.x < row.length() and row[tile.x] == "K":
			_rows[tile.y] = _set_char(row, tile.x, ".")
	return true
