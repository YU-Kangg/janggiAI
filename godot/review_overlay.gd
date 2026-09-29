extends Control

var board: GridContainer
var arrow := ""
var marked_square := ""
var grade := ""
const SYMBOLS := {"brilliant": "!!", "best": "★", "excellent": "✓", "good": "✓", "inaccuracy": "?!", "mistake": "?", "blunder": "??"}
const COLORS := {"brilliant": Color("27a6ab"), "best": Color("719b4a"), "excellent": Color("83a56b"), "good": Color("83a56b"), "inaccuracy": Color("d8a639"), "mistake": Color("d98440"), "blunder": Color("cf5752")}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5
	resized.connect(queue_redraw)

func point(square: String) -> Vector2:
	for cell in board.get_children():
		if cell.tooltip_text == square:
			return cell.position + cell.size / 2.0
	return Vector2(-100, -100)

func set_markers(best_move: String, destination: String, classification: String) -> void:
	arrow = best_move
	marked_square = destination
	grade = classification
	queue_redraw()

func _draw() -> void:
	if board == null or board.get_child_count() != 90:
		return
	var regex := RegEx.new()
	regex.compile("^([a-i](?:10|[1-9]))([a-i](?:10|[1-9]))$")
	var move := regex.search(arrow)
	if move:
		var start := point(move.get_string(1))
		var end := point(move.get_string(2))
		var color := Color(0.28, 0.62, 0.35, 0.85)
		if start == end:
			draw_arc(start, 15, 0, TAU, 32, color, 5, true)
		else:
			var direction := (end - start).normalized()
			var normal := direction.orthogonal()
			draw_line(start, end - direction * 9, color, 7, true)
			draw_colored_polygon(PackedVector2Array([end, end - direction * 19 + normal * 10, end - direction * 19 - normal * 10]), color)
	if marked_square != "" and SYMBOLS.has(grade):
		var cell_size: Vector2 = board.get_child(0).size
		var center := point(marked_square) + Vector2(-cell_size.x * 0.31, -cell_size.y * 0.31)
		center.x = clampf(center.x, 12, size.x - 12)
		center.y = clampf(center.y, 12, size.y - 12)
		draw_circle(center, 12, COLORS[grade])
		var font := ThemeDB.fallback_font
		var symbol: String = SYMBOLS[grade]
		var width := font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(font, center + Vector2(-width / 2, 5), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
