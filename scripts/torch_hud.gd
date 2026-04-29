extends Control

const GAME_FONT := preload("res://assets/alagard.ttf")

@onready var _icon: TextureRect = %TorchIcon
@onready var _count: Label = %TorchCount


func _ready() -> void:
	_count.add_theme_font_override("font", GAME_FONT)
	call_deferred("_connect_player")


func _connect_player() -> void:
	var p := get_tree().get_first_node_in_group("player") as GridPlayer
	if p == null:
		push_warning("TorchHud: no node in group 'player'")
		return
	if not p.torches_changed.is_connected(_on_torches_changed):
		p.torches_changed.connect(_on_torches_changed)
	_on_torches_changed(p.torches_held)


func _on_torches_changed(n: int) -> void:
	_count.text = str(n)
