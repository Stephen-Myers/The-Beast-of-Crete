extends CanvasLayer
class_name GameOverOverlay
## Fullscreen game-over overlay built entirely in code.
## Call setup() after adding to the scene tree.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const MAIN_SCENE := "res://scenes/main.tscn"
const GAME_FONT := preload("res://assets/alagard.ttf")

var _score: int = 0
var _floor: int = 1
var _time_sec: float = 0.0


func setup(score: int, floor_num: int, elapsed_sec: float) -> void:
	_score = score
	_floor = floor_num
	_time_sec = elapsed_sec


func _ready() -> void:
	layer = 100  # render above everything

	# ── Dark overlay background ───────────────────────────────
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP  # block input to game
	add_child(bg)

	# ── Center container ──────────────────────────────────────
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)

	# ── Solid panel behind text for readability ───────────────
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.92)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 48
	style.content_margin_right = 48
	style.content_margin_top = 36
	style.content_margin_bottom = 36
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# ── GAME OVER title ──────────────────────────────────────
	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(title, 72)
	title.add_theme_color_override("font_color", Color(0.88, 0.2, 0.2))
	vbox.add_child(title)

	# ── Spacer ────────────────────────────────────────────────
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# ── Stats ─────────────────────────────────────────────────
	_add_stat(vbox, "Score", str(_score))
	_add_stat(vbox, "Floor Reached", str(_floor))
	var m := int(_time_sec) / 60
	var s := int(_time_sec) % 60
	_add_stat(vbox, "Time Survived", "%d:%02d" % [m, s])

	# ── Spacer ────────────────────────────────────────────────
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer2)

	# ── Buttons ───────────────────────────────────────────────
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 28)
	vbox.add_child(btn_box)

	var btn_play := Button.new()
	btn_play.text = "Play Again"
	btn_play.custom_minimum_size = Vector2(180, 50)
	_apply_font(btn_play, 24)
	btn_play.add_theme_color_override("font_color", Color.WHITE)
	btn_play.pressed.connect(_on_play_again)
	btn_box.add_child(btn_play)

	var btn_menu := Button.new()
	btn_menu.text = "Main Menu"
	btn_menu.custom_minimum_size = Vector2(180, 50)
	_apply_font(btn_menu, 24)
	btn_menu.add_theme_color_override("font_color", Color.WHITE)
	btn_menu.pressed.connect(_on_main_menu)
	btn_box.add_child(btn_menu)

	# Start game over music
	AudioManager.play_game_over_music()


func _apply_font(node: Control, size: int) -> void:
	node.add_theme_font_override("font", GAME_FONT)
	node.add_theme_font_size_override("font_size", size)
	if node is Label:
		node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		node.add_theme_constant_override("shadow_offset_x", 2)
		node.add_theme_constant_override("shadow_offset_y", 2)


func _add_stat(parent: VBoxContainer, label_text: String, value_text: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text + ":"
	_apply_font(lbl, 28)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hbox.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	_apply_font(val, 28)
	val.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(val)


func _on_play_again() -> void:
	AudioManager.play_menu_button()
	AudioManager.stop_game_over_music()
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_main_menu() -> void:
	AudioManager.play_menu_button()
	AudioManager.stop_game_over_music()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
