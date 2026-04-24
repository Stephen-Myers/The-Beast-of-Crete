extends Label


func _ready() -> void:
	call_deferred("_connect_maze")


func _connect_maze() -> void:
	var maze := get_node("../../../Maze") as MazeController
	if maze == null:
		push_warning("LevelLabelHud: Maze node not found")
		return
	if not maze.floor_changed.is_connected(_on_floor_changed):
		maze.floor_changed.connect(_on_floor_changed)
	_on_floor_changed(maze.current_floor)


func _on_floor_changed(floor_num: int) -> void:
	text = "Level %d" % floor_num
