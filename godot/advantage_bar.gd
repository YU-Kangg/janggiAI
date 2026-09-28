extends Control

# Engine centipawns describe advantage, not a win probability.
var cho_share := 0.5
var available := false
var flipped := false

func _ready() -> void:
	custom_minimum_size.x = 22
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_evaluation(evaluation: Dictionary, han_at_bottom: bool) -> void:
	flipped = han_at_bottom
	available = evaluation.get("unit", "") in ["cp", "mate"] and evaluation.get("cho") != null
	cho_share = 0.5
	if available:
		var value := float(evaluation.cho)
		cho_share = clampf(0.5 + atan(value / 400.0) / PI, 0.04, 0.96) if evaluation.unit == "cp" else (0.98 if value > 0 else 0.02)
	queue_redraw()

func _draw() -> void:
	var top_share := cho_share if flipped else 1.0 - cho_share
	var top_color := Color("8bafc7") if flipped else Color("dba398")
	var bottom_color := Color("dba398") if flipped else Color("8bafc7")
	if not available:
		top_color = Color("d8cec1")
		bottom_color = Color("ece2d5")
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, size.y * top_share)), top_color)
	draw_rect(Rect2(Vector2(0, size.y * top_share), Vector2(size.x, size.y * (1.0 - top_share))), bottom_color)
	draw_line(Vector2(0, size.y / 2), Vector2(size.x, size.y / 2), Color("fffaf2"), 2)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(3, 20), "초" if flipped else "한", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("54483e"))
	draw_string(font, Vector2(3, size.y - 8), "한" if flipped else "초", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("54483e"))
