extends Label

const GAME_FONT := preload("res://assets/alagard.ttf")


func _ready() -> void:
	add_theme_font_override("font", GAME_FONT)
	call_deferred("_connect_player")


func _connect_player() -> void:
	var p := get_tree().get_first_node_in_group("player") as GridPlayer
	if p == null:
		push_warning("ScoreHud: no node in group 'player'")
		return
	if not p.score_changed.is_connected(_on_score_changed):
		p.score_changed.connect(_on_score_changed)
	_on_score_changed(p.score)


func _on_score_changed(total: int) -> void:
	text = "Score: %d" % total
