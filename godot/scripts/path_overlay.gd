extends Control
class_name PathOverlay

var _points: Array = []
var _color: Color = Color(1.0, 0.48, 0.0, 1.0)
var _line_width: float = 4.0
var _remaining: float = 0.0

func _process(delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining = max(0.0, _remaining - delta)
	if _remaining == 0.0:
		_points.clear()
		update()

func show_path(points: Array, color: Color, duration_sec: float) -> void:
	_points = points.duplicate()
	_color = color
	_remaining = duration_sec
	set_process(true)
	update()

func clear_path() -> void:
	_points.clear()
	_remaining = 0.0
	update()

func _draw() -> void:
	if _points.size() < 2:
		return
	for i in range(_points.size() - 1):
		draw_line(_points[i], _points[i + 1], _color, _line_width, true)
