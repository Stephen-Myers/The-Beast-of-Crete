extends Node2D
class_name MazeController

const TILE_SIZE := 32
const COLOR_FLOOR := Color(0.08, 0.08, 0.09)
const COLOR_WALL := Color(0.45, 0.45, 0.5)

## '#' = wall block, '.' / 'P' = floor. One 'P' = spawn.
const MAZE_LAYOUT := """
########.########
#.#.....P.#.....#
#.#.#####.#.###.#
#.#.#...#.#.#...#
#.#.###.#.#.#.###
#.#...#.#.#.#...#
#.###.#.#.#.###.#
#.#...#...#...#.#
#.#.###.#######.#
#.#.#.#.#.......#
#.#.#.#.###.###.#
#.#.#.......#...#
#.#.#########.###
#.#...#...#...#.#
#.###.#.#.#.###.#
......#.#.......#
.################
"""

var _rows: PackedStringArray = []

func _ready() -> void:
	_rows.clear()
	for raw: String in MAZE_LAYOUT.strip_edges().split("\n"):
		var line := raw.replace("\r", "").strip_edges()
		if line.is_empty():
			continue
		_rows.append(line)

	var spawn_cell := Vector2i(8, 1)
	for y in range(_rows.size()):
		var row: String = _rows[y]
		for x in range(row.length()):
			if row[x] == "P":
				spawn_cell = Vector2i(x, y)

	var floors := Node2D.new()
	floors.name = "Floors"
	floors.z_index = 0
	add_child(floors)

	var walls := Node2D.new()
	walls.name = "Walls"
	walls.z_index = 1
	add_child(walls)

	for y in range(_rows.size()):
		var row: String = _rows[y]
		for x in range(row.length()):
			var center := Vector2(x + 0.5, y + 0.5) * TILE_SIZE
			if row[x] == "#":
				_add_wall_block(walls, center)
			else:
				_add_floor_tile(floors, center)

	var player := get_node_or_null("../Player")
	if player and player.has_method("initialize_grid"):
		player.initialize_grid(self, spawn_cell)

	var cam := get_node_or_null("../Camera2D") as Camera2D
	if cam and _rows.size() > 0:
		var w := _rows[0].length()
		var h := _rows.size()
		cam.global_position = Vector2(w, h) * TILE_SIZE / 2.0
		cam.make_current()
		await get_tree().process_frame
		_fit_camera_to_maze(cam, w, h)


func _add_floor_tile(parent: Node2D, center: Vector2) -> void:
	var poly := Polygon2D.new()
	poly.color = COLOR_FLOOR
	var h := TILE_SIZE / 2.0
	poly.polygon = PackedVector2Array(
		[Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]
	)
	poly.position = center
	parent.add_child(poly)


func _add_wall_block(parent: Node2D, center: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	shape.shape = rect
	body.add_child(shape)
	var poly := Polygon2D.new()
	poly.color = COLOR_WALL
	var h := TILE_SIZE / 2.0
	poly.polygon = PackedVector2Array(
		[Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]
	)
	body.add_child(poly)
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
