# Temporary red-block “enemy” for maze testing.
#
# To remove when the real enemy is ready:
#   1. Set Maze → Use Placeholder Enemy = OFF (or delete this file).
#   2. Delete res://scripts/placeholder_enemy_maze.gd
#   3. In maze.gd, remove: the preload, @export use_placeholder_enemy,
#      and the PlaceholderEnemyMaze.spawn(...) call in _ready().

extends RefCounted
class_name PlaceholderEnemyMaze

const COLOR_ENEMY := Color(0.78, 0.18, 0.22)


static func spawn(maze: MazeController, enemies_root: Node2D) -> void:
	var cell := _pick_enemy_cell(maze)
	if cell.x < 0:
		return
	maze.register_enemy_cell(cell)
	var center := maze.tile_to_world_center(cell)
	_add_enemy_block(enemies_root, center, maze.TILE_SIZE)


static func _pick_enemy_cell(maze: MazeController) -> Vector2i:
	var candidates: Array[Vector2i] = []
	var rows := maze.enemy_grid_rows()
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			if row[x] != ".":
				continue
			var c := Vector2i(x, y)
			if c == maze.spawn_cell or c == maze.exit_cell:
				continue
			if abs(c.x - maze.spawn_cell.x) + abs(c.y - maze.spawn_cell.y) < 5:
				continue
			candidates.append(c)
	if candidates.is_empty():
		for y in range(rows.size()):
			var row2: String = rows[y]
			for x in range(row2.length()):
				if row2[x] == ".":
					var c2 := Vector2i(x, y)
					if c2 != maze.spawn_cell and c2 != maze.exit_cell:
						candidates.append(c2)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	candidates.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return candidates[candidates.size() / 2]


static func _add_enemy_block(parent: Node2D, center: Vector2, tile: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	var shape_n := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(tile, tile)
	shape_n.shape = rect
	body.add_child(shape_n)
	var poly := Polygon2D.new()
	poly.color = COLOR_ENEMY
	var h := tile / 2.0
	poly.polygon = PackedVector2Array(
		[Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]
	)
	body.add_child(poly)
	parent.add_child(body)
