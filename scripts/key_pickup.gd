extends Node2D
class_name KeyPickup

var grid_cell: Vector2i = Vector2i.ZERO


func setup(cell: Vector2i, world_center: Vector2, tile_px: float, icon: Texture2D) -> void:
	grid_cell = cell
	position = world_center
	z_index = 2
	z_as_relative = true
	for c in get_children():
		c.queue_free()
	if icon != null:
		var spr := Sprite2D.new()
		spr.texture = icon
		spr.centered = true
		var sz := icon.get_size()
		var max_sz := maxf(sz.x, sz.y)
		var fit := (tile_px * 1.4) / max_sz if max_sz > 0.0 else 1.0
		spr.scale = Vector2(fit, fit)
		add_child(spr)
	else:
		var poly := Polygon2D.new()
		poly.color = Color(0.92, 0.75, 0.2)
		var h := tile_px * 0.45
		poly.polygon = PackedVector2Array([
			Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h),
		])
		add_child(poly)
