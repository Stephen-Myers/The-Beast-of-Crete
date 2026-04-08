extends Control

@onready var btn_back: Button = %BackButton

func _ready() -> void:
	btn_back.pressed.connect(_on_back)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
