extends CanvasLayer
class_name HealthHud

## Should match the number of TextureRect children under %BlocksRow (default: 3).
@export var slot_count: int = 3
## Icon for each filled hit; leave empty for solid placeholder blocks.
@export var block_texture: Texture2D
## Shown for lost hits; if null, empty slots use modulate only.
@export var block_empty_texture: Texture2D
## Default size for every hit block (Inspector on this HealthHud node).
@export var block_size: Vector2 = Vector2(36, 36)
## Optional per-slot sizes (Hit1 = index 0, etc.). Use (0, 0) for an entry to keep [block_size] for that slot.
@export var block_sizes: Array[Vector2] = []
@export var separation: int = 10
## Pixels from the **viewport’s top-left** to this HUD. Lower = closer to the corner; e.g. (0, 0) is flush.
@export var corner_offset: Vector2 = Vector2(0, 0)
## Padding **inside** the panel, between the panel edge and the icons.
@export var margin_left: int = 8
@export var margin_top: int = 8
@export var margin_right: int = 8
@export var margin_bottom: int = 8

var _blocks: Array[TextureRect] = []

@onready var _margin: MarginContainer = %HealthMargin
@onready var _blocks_row: HBoxContainer = %BlocksRow


func _ready() -> void:
	_collect_blocks()
	if _blocks.size() != slot_count:
		slot_count = _blocks.size()
	_apply_globals()
	call_deferred("_connect_player")


func _collect_blocks() -> void:
	_blocks.clear()
	for c in _blocks_row.get_children():
		if c is TextureRect:
			_blocks.append(c as TextureRect)


func _apply_globals() -> void:
	_margin.add_theme_constant_override("margin_left", margin_left)
	_margin.add_theme_constant_override("margin_top", margin_top)
	_margin.add_theme_constant_override("margin_right", margin_right)
	_margin.add_theme_constant_override("margin_bottom", margin_bottom)
	_blocks_row.add_theme_constant_override("separation", separation)

	var row_w: float = 0.0
	var row_h: float = 0.0
	for i in _blocks.size():
		var sz_hint: Vector2 = _size_for_slot(i)
		row_w += sz_hint.x
		row_h = maxf(row_h, sz_hint.y)
	if _blocks.size() > 1:
		row_w += float(separation * (_blocks.size() - 1))
	var pad_x := float(margin_left + margin_right)
	var pad_y := float(margin_top + margin_bottom)
	_margin.anchor_left = 0.0
	_margin.anchor_top = 0.0
	_margin.anchor_right = 0.0
	_margin.anchor_bottom = 0.0
	_margin.offset_left = corner_offset.x
	_margin.offset_top = corner_offset.y
	_margin.offset_right = corner_offset.x + row_w + pad_x
	_margin.offset_bottom = corner_offset.y + row_h + pad_y

	for i in _blocks.size():
		var sz: Vector2 = _size_for_slot(i)
		var tr: TextureRect = _blocks[i]
		tr.custom_minimum_size = sz
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if block_texture != null:
			tr.texture = block_texture
		else:
			tr.texture = _placeholder_texture_for_size(sz)


func _size_for_slot(index: int) -> Vector2:
	if index < block_sizes.size():
		var o: Vector2 = block_sizes[index]
		if o.x > 0.0 and o.y > 0.0:
			return o
	return block_size


func _placeholder_texture_for_size(sz: Vector2) -> ImageTexture:
	var w := maxi(1, int(sz.x))
	var h := maxi(1, int(sz.y))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.88, 0.3, 0.32, 1.0))
	return ImageTexture.create_from_image(img)


func _connect_player() -> void:
	var p := get_tree().get_first_node_in_group("player") as GridPlayer
	if p == null:
		push_warning("HealthHud: no node in group 'player'")
		return
	if not p.health_changed.is_connected(_on_health_changed):
		p.health_changed.connect(_on_health_changed)
	_on_health_changed(p.health, p.max_health)


func _on_health_changed(current: int, _maximum: int) -> void:
	for i in _blocks.size():
		var filled := i < clampi(current, 0, _blocks.size())
		var tr: TextureRect = _blocks[i]
		if block_texture != null and block_empty_texture != null:
			tr.texture = block_texture if filled else block_empty_texture
			tr.modulate = Color.WHITE
		elif block_texture != null:
			tr.texture = block_texture
			tr.modulate = Color.WHITE if filled else Color(0.45, 0.45, 0.45, 0.55)
		else:
			tr.modulate = Color.WHITE if filled else Color(0.55, 0.55, 0.55, 0.55)
