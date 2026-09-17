extends Control

signal ply_selected(ply: int)

var values: Array = []
var selected_ply := 0

func _ready() -> void:
	custom_minimum_size.y = 90
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func set_results(results: Array) -> void:
	values = []
	if not results.is_empty():
		values.append(evaluation_value(results[0].get("analysis", {}).get("before")))
		for item in results:
			values.append(evaluation_value(item.get("analysis", {}).get("after")))
	selected_ply = clampi(selected_ply, 0, maxi(0, values.size() - 1))
	queue_redraw()

func evaluation_value(analysis: Variant) -> Variant:
	if not analysis is Dictionary:
		return null
	var evaluation: Dictionary = analysis.get("evaluation", {})
	return float(evaluation.get("cho", 0)) if evaluation.get("unit", "") == "cp" else null

func select_ply(ply: int) -> void:
	selected_ply = clampi(ply, 0, maxi(0, values.size() - 1))
	queue_redraw()

func point_for(index: int, maximum: float) -> Vector2:
	var x := 8.0 + (size.x - 16.0) * float(index) / float(maxi(1, values.size() - 1))
	var value := 0.0 if values[index] == null else float(values[index])
	var y := size.y * 0.5 - clampf(value / maximum, -1.0, 1.0) * (size.y * 0.5 - 10.0)
	return Vector2(x, y)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.12, 0.12), true)
	draw_line(Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.5), Color(0.45, 0.45, 0.45), 1.0)
	if values.size() < 2:
		return
	var maximum := 100.0
	for value in values:
		if value != null:
			maximum = maxf(maximum, absf(float(value)))
	var previous: Variant = null
	for index in range(values.size()):
		if values[index] == null:
			previous = null
			continue
		var point := point_for(index, maximum)
		if previous != null:
			draw_line(previous, point, Color(0.4, 0.85, 1.0), 3.0, true)
		previous = point
	var marker := point_for(selected_ply, maximum)
	draw_circle(marker, 6.0, Color(1.0, 0.78, 0.2))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and values.size() > 1:
		var ratio := clampf(event.position.x / maxf(1.0, size.x), 0.0, 1.0)
		ply_selected.emit(roundi(ratio * float(values.size() - 1)))
		accept_event()
