extends Label

var _elapsed_sec: float = 0.0


func _process(delta: float) -> void:
	_elapsed_sec += delta
	var total := int(floor(_elapsed_sec))
	var m := total / 60
	var s := total % 60
	text = "%d:%02d" % [m, s]
