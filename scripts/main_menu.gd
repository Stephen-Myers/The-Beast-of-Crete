extends Control

@onready var btn_play: Button = %PlayButton
@onready var btn_instructions: Button = %InstructionsButton
@onready var btn_credits: Button = %CreditsButton
@onready var btn_exit: Button = %ExitButton


func _ready() -> void:
	btn_play.pressed.connect(_on_play)
	btn_instructions.pressed.connect(_on_instructions)
	btn_credits.pressed.connect(_on_credits)
	btn_exit.pressed.connect(_on_exit)
	AudioManager.play_menu_music()  


func _on_play() -> void:
	AudioManager.play_menu_button() 
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_instructions() -> void:
	AudioManager.play_menu_button() 
	get_tree().change_scene_to_file("res://scenes/instructions.tscn")


func _on_credits() -> void:
	AudioManager.play_menu_button() 
	get_tree().change_scene_to_file("res://scenes/credits.tscn")


func _on_exit() -> void:
	AudioManager.play_menu_button() 
	get_tree().quit()
