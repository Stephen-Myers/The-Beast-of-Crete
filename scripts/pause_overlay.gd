extends CanvasLayer
class_name PauseOverlay
## Fullscreen pause overlay. Freezes the scene tree while active.
## process_mode is set to ALWAYS so this node still receives input while paused.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const GAME_FONT := preload("res://assets/alagard.ttf")


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep receiving input while paused

	# ── Dark overlay background ───────────────────────────────
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# ── Center container ──────────────────────────────────────
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)

	# ── Solid panel behind text ───────────────────────────────
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

	# ── PAUSED title ──────────────────────────────────────────
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(title, 72)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	# ── Spacer ────────────────────────────────────────────────
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	# ── Buttons ───────────────────────────────────────────────
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 28)
	vbox.add_child(btn_box)

	var btn_resume := Button.new()
	btn_resume.text = "Resume"
	btn_resume.custom_minimum_size = Vector2(180, 50)
	_apply_font(btn_resume, 24)
	btn_resume.add_theme_color_override("font_color", Color.WHITE)
	btn_resume.pressed.connect(_on_resume)
	btn_box.add_child(btn_resume)

	var btn_menu := Button.new()
	btn_menu.text = "Main Menu"
	btn_menu.custom_minimum_size = Vector2(180, 50)
	_apply_font(btn_menu, 24)
	btn_menu.add_theme_color_override("font_color", Color.WHITE)
	btn_menu.pressed.connect(_on_main_menu)
	btn_box.add_child(btn_menu)

	# Pause the game
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var e := event as InputEventKey
		if e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
			_on_resume()
			get_viewport().set_input_as_handled()


func _apply_font(node: Control, size: int) -> void:
	node.add_theme_font_override("font", GAME_FONT)
	node.add_theme_font_size_override("font_size", size)
	if node is Label:
		node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		node.add_theme_constant_override("shadow_offset_x", 2)
		node.add_theme_constant_override("shadow_offset_y", 2)


func _on_resume() -> void:
	AudioManager.play_menu_button()
	get_tree().paused = false
	queue_free()


func _on_main_menu() -> void:
	AudioManager.play_menu_button()
	get_tree().paused = false
	AudioManager.stop_all_music()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)