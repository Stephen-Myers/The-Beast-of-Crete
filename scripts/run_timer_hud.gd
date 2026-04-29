extends Label

const GAME_FONT := preload("res://assets/alagard.ttf")

var _elapsed_sec: float = 0.0
var _running: bool = true


func _ready() -> void:
	add_theme_font_override("font", GAME_FONT)
	call_deferred("_connect_player")


func _connect_player() -> void:
	var p := get_tree().get_first_node_in_group("player") as GridPlayer
	if p == null:
		return
	if not p.health_changed.is_connected(_on_health_changed):
		p.health_changed.connect(_on_health_changed)


func _on_health_changed(current: int, _maximum: int) -> void:
	if current <= 0:
		_running = false


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed_sec += delta
	var total := int(floor(_elapsed_sec))
	var m := total / 60
	var s := total % 60
	text = "%d:%02d" % [m, s]
