extends Node2D
class_name TorchPickup

const FRAME_COUNT := 4
const FRAME_INTERVAL := 0.15
const TORCH_SCENE := preload("res://assets/items/torch.png")

var _frame: int = 0
var _timer: float = 0.0
var _sprite: Sprite2D

func setup(cell: Vector2i, center: Vector2, tile_size: int) -> void:
	position = center
	z_index = 2

	var atlas := AtlasTexture.new()
	atlas.atlas = TORCH_SCENE
	atlas.region = Rect2(0, 0, tile_size, tile_size)
	atlas.filter_clip = true

	_sprite = Sprite2D.new()
	_sprite.texture = atlas
	add_child(_sprite)

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= FRAME_INTERVAL:
		_timer -= FRAME_INTERVAL
		_frame = (_frame + 1) % FRAME_COUNT
		var atlas := _sprite.texture as AtlasTexture
		if atlas:
			atlas.region = Rect2(_frame * 8, 0, 8, 8)
