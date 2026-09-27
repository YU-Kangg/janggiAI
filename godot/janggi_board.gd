extends GridContainer

# Lines pass through the centers of the same controls that receive input.
func _ready() -> void:
	add_theme_constant_override("h_separation", 0)
	add_theme_constant_override("v_separation", 0)
	resized.connect(_resize_cells)
	sort_children.connect(queue_redraw)

func _resize_cells() -> void:
	for cell in get_children():
		cell.custom_minimum_size.y = maxf(40.0, size.x / 9.0)
	queue_redraw()

func _draw() -> void:
	if get_child_count() != 90:
		return
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("f5ecdc")
	surface.border_color = Color("c7b79d")
	surface.set_border_width_all(1)
	surface.set_corner_radius_all(12)
	draw_style_box(surface, Rect2(Vector2.ZERO, size))
	var ink := Color("9b8c77")
	for file in range(9):
		draw_line(center(file, 0), center(file, 9), ink, 1.2, true)
	for row in range(10):
		draw_line(center(0, row), center(8, row), ink, 1.2, true)
	for row in [0, 7]:
		draw_line(center(3, row), center(5, row + 2), ink, 1.2, true)
		draw_line(center(5, row), center(3, row + 2), ink, 1.2, true)
	for row in [2, 3, 6, 7]:
		var files := [1, 7] if row == 2 or row == 7 else [0, 2, 4, 6, 8]
		for file in files:
			var point := center(file, row)
			for direction in [-1, 1]:
				if (file == 0 and direction == -1) or (file == 8 and direction == 1):
					continue
				for vertical in [-1, 1]:
					var corner := point + Vector2(direction * 4, vertical * 4)
					draw_line(corner, corner + Vector2(direction * 4, 0), ink, 1.0, true)
					draw_line(corner, corner + Vector2(0, vertical * 4), ink, 1.0, true)

func center(file: int, row: int) -> Vector2:
	var cell: Control = get_child(row * 9 + file)
	return cell.position + cell.size / 2.0
