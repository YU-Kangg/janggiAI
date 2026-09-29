extends Control

# Engine centipawns describe advantage, not a win probability.
var cho_share := 0.5
var available := false
var flipped := false
var score_text := "—"
var delta_text := ""

func _ready() -> void:
	custom_minimum_size.x = 48
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_evaluation(evaluation: Dictionary, han_at_bottom: bool, before: Dictionary = {}) -> void:
	flipped = han_at_bottom
	available = evaluation.get("unit", "") in ["cp", "mate"] and evaluation.get("cho") != null
	cho_share = 0.5
	score_text = "—"
	delta_text = ""
	if available:
		var value := float(evaluation.cho)
		score_text = "%+.1f" % (value / 100.0) if evaluation.unit == "cp" else ("초승" if value > 0 else "한승")
		if evaluation.unit == "cp" and before.get("unit", "") == "cp" and before.get("cho") != null:
			delta_text = "%+.1f" % ((value - float(before.cho)) / 100.0)
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
	var plate := Rect2(0, size.y * 0.5 - 32, size.x, 64 if delta_text != "" else 32)
	draw_rect(plate, Color("fff7e8"))
	draw_string(font, Vector2(1, plate.position.y + 20), score_text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 2, 15, Color("54483e"))
	if delta_text != "":
		draw_string(font, Vector2(1, plate.position.y + 39), "변화", HORIZONTAL_ALIGNMENT_CENTER, size.x - 2, 10, Color("75685c"))
		draw_string(font, Vector2(1, plate.position.y + 54), delta_text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 2, 13, Color("54483e"))
	tooltip_text = "초 기준 우세 점수 · +는 초, −는 한 우세\n변화: 직전 위치 대비 초의 평가 변화"
