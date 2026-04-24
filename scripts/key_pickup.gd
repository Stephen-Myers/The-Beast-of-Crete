extends Node2D
class_name KeyPickup

const _FALLBACK_KEY_TEXTURE := preload("res://assets/items/key.png")

var grid_cell: Vector2i = Vector2i.ZERO


func setup(cell: Vector2i, world_center: Vector2, tile_px: float, icon: Texture2D) -> void:
	grid_cell = cell
	position = world_center
	z_index = 2
	z_as_relative = true
	for c in get_children():
		c.queue_free()
	var tex: Texture2D = icon if icon != null else _FALLBACK_KEY_TEXTURE
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = true
	var sz := tex.get_size()
	var max_sz := maxf(sz.x, sz.y)
	var fit := (tile_px * 1.4) / max_sz if max_sz > 0.0 else 1.0
	spr.scale = Vector2(fit, fit)
	add_child(spr)
