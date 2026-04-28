extends Node2D
class_name FogOfWar

## Grid-based fog of war. No raycasting or shaders needed.
## - Immediate 1-tile radius around player is always visible (including diagonals)
## - Cardinal directions (N/S/E/W) see down corridors up to sight_range tiles
## - Previously seen tiles show faint wall outlines (wall memory)
## - Everything else is pitch black

## How far the player can see down a straight corridor
@export var sight_range: int = 5

# Tile size must match MazeController
var _tile_size: int = 8
var _grid_w: int = 0
var _grid_h: int = 0

# 2D array of Polygon2D nodes (the dark overlay per tile)
var _fog_tiles: Array = []
# Dictionary of Vector2i -> true for tiles the player has ever seen
var _seen_tiles: Dictionary = {}
# Current set of visible tiles
var _visible_tiles: Dictionary = {}

# Colors
const COLOR_HIDDEN := Color(0, 0, 0, 1.0) # never seen: pure black
const COLOR_REMEMBERED := Color(0, 0, 0, 0.3) # seen before: dim
const COLOR_VISIBLE := Color(0, 0, 0, 0.0) # currently visible: transparent

# Polygon shape (set once in setup, reused in update)
var _poly_padded: PackedVector2Array


func setup(rows: PackedStringArray, tile_size: int) -> void:
	_tile_size = tile_size
	_grid_h = rows.size()
	_grid_w = rows[0].length() if _grid_h > 0 else 0

	var half_tile := _tile_size / 2.0
	var pad := 4.0

	# Pre-build the two polygon shapes
	_poly_padded = PackedVector2Array([
		Vector2(-half_tile - pad, -half_tile - pad),
		Vector2(half_tile + pad, -half_tile - pad),
		Vector2(half_tile + pad, half_tile + pad),
		Vector2(-half_tile - pad, half_tile + pad)
	])

	# Create a black overlay rect for every tile
	_fog_tiles.clear()
	for y in range(_grid_h):
		var row_arr := []
		for x in range(_grid_w):
			var fog := Polygon2D.new()
			fog.color = COLOR_HIDDEN
			fog.polygon = _poly_padded
			fog.position = Vector2(x + 0.5, y + 0.5) * _tile_size
			add_child(fog)
			row_arr.append(fog)
		_fog_tiles.append(row_arr)


func update_visibility(player_tile: Vector2i, maze: MazeController) -> void:
	update_visibility_multi([player_tile], maze)


func update_visibility_multi(viewer_tiles: Array, maze: MazeController) -> void:
	_visible_tiles.clear()

	for viewer in viewer_tiles:
		# 1. Reveal immediate 3x3 around each viewer
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var tile: Vector2i = viewer + Vector2i(dx, dy)
				if _in_bounds(tile):
					_visible_tiles[tile] = true

		# 2. Cardinal line-of-sight in all 4 directions
		var cardinal_dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]
		for dir in cardinal_dirs:
			_cast_cardinal(viewer, dir, maze)

	# 3. Mark all visible tiles as seen (wall memory)
	for tile in _visible_tiles:
		_seen_tiles[tile] = true

	# 4. Update fog overlay colors
	for y in range(_grid_h):
		for x in range(_grid_w):
			var tile := Vector2i(x, y)
			var fog: Polygon2D = _fog_tiles[y][x]
			if _visible_tiles.has(tile):
				fog.color = COLOR_VISIBLE
			elif _seen_tiles.has(tile):
				fog.color = COLOR_REMEMBERED
			else:
				fog.color = COLOR_HIDDEN


func _cast_cardinal(origin: Vector2i, dir: Vector2i, maze: MazeController) -> void:
	var perp := Vector2i(dir.y, dir.x)
	for i in range(0, sight_range + 1):
		var tile := origin + dir * i
		if not _in_bounds(tile):
			break
		# Reveal the center tile and both walls flanking it
		_visible_tiles[tile] = true
		for side in [-1, 1]:
			var side_tile: Vector2i = tile + perp * side
			if _in_bounds(side_tile):
				_visible_tiles[side_tile] = true
		# Stop at walls
		if not maze.is_walkable(tile):
			break


func _in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < _grid_w and tile.y >= 0 and tile.y < _grid_h

func is_tile_visible(tile: Vector2i) -> bool:
	return _visible_tiles.has(tile)
