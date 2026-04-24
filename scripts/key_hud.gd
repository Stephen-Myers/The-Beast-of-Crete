extends Control

## Layout, texture, and sizes for the key icon are set on the KeyIcon node (and this root) in the editor — nothing here overrides them at runtime.

@onready var _icon: TextureRect = %KeyIcon
@onready var _count: Label = %KeyCount


func _ready() -> void:
	call_deferred("_connect_player")


func _connect_player() -> void:
	var p := get_tree().get_first_node_in_group("player") as GridPlayer
	if p == null:
		push_warning("KeyHud: no node in group 'player'")
		return
	if not p.keys_changed.is_connected(_on_keys_changed):
		p.keys_changed.connect(_on_keys_changed)
	_on_keys_changed(p.keys_held)


func _on_keys_changed(n: int) -> void:
	_count.text = str(n)
