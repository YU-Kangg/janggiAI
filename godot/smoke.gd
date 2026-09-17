extends SceneTree

var app

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, detail: String) -> void:
	if not condition:
		push_error(detail)
		quit(1)
		assert(condition, detail)

func wait_idle() -> void:
	while app.pending:
		await process_frame

func run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.timer.stop()
	await wait_idle()
	check(not app.state.is_empty(), "initial HTTP connection")
	check(app.squares.size() == 90, "90 board squares")
	check(not app.device_engine.available() and app.device_recommend.disabled, "desktop fallback without Android engine")
	app.act("reset", {"mode": "ai", "humanSide": "cho"})
	await wait_idle()
	app.squares["a4"].pressed.emit()
	check(app.selected == "a4", "piece selection")
	app.squares["b4"].pressed.emit()
	await wait_idle()
	check(app.state.moves.size() >= 1 and app.state.moves[0] == "a4b4", "legal touch action")
	for attempt in range(100):
		if app.state.moves.size() == 2:
			break
		await create_timer(0.1).timeout
		app.request_state()
		await wait_idle()
	check(app.state.moves.size() == 2 and app.state.turn == "cho", "NNUE AI reply")
	var live_fen: String = app.state.fen
	app.show_review(0)
	await wait_idle()
	check(app.review.moves.size() == 0 and app.state.moves.size() == 2, "review preserves live history")
	check(app.squares["a4"].disabled and app.action_buttons[2].disabled, "review blocks move and undo")
	app.act("undo")
	check(not app.pending, "review action guard")
	app.request_state()
	await wait_idle()
	check(not app.review.is_empty(), "unchanged polling preserves review")
	app.show_review(1)
	await wait_idle()
	check(app.review.moves.size() == 1 and app.state.fen == live_fen, "middle position")
	check(not app.review_analysis_button.disabled, "played move can request server analysis")
	app.start_review_analysis()
	await wait_idle()
	check(not app.review_analysis.is_empty(), "server review analysis response")
	check(app.review_analysis.playedMove == "a4b4", "analysis targets selected move")
	check(app.review_analysis.analysis.before.evaluation.unit == "cp", "before evaluation")
	check(app.review_analysis.analysis.after.evaluation.unit == "cp", "after evaluation")
	check(app.message.text.contains("손실"), "analysis result display")
	check(not app.message.text.contains("a4") and not app.message.text.contains("→"), "move coordinates hidden from result text")
	check(app.analysis_stage == 1 and app.analysis_preview.fen == app.review_analysis.beforeFen, "recommendation source highlight")
	await create_timer(0.6).timeout
	check(app.analysis_stage == 2 and app.analysis_preview.fen == app.review_analysis.recommendedFen, "recommended piece movement")
	app.start_variation()
	await wait_idle()
	check(not app.variation.is_empty() and app.variation_start_ply == 1, "variation starts from review position")
	check(app.variation.turn == "han" and app.variation.legalMoves.has("a7b7"), "both-side legal variation position")
	check(app.score_panel.text.contains("초 72.0 / 한 73.5") and app.score_panel.text.contains("기기 형세 사용 불가"), "material score and desktop engine fallback")
	app.squares["a7"].pressed.emit()
	app.squares["b7"].pressed.emit()
	await wait_idle()
	check(app.variation_moves == ["a7b7"] and app.variation.turn == "cho", "variation move without live mutation")
	check(app.state.fen == live_fen and app.state.moves.size() == 2, "variation preserves original game")
	app.undo_variation()
	await wait_idle()
	check(app.variation_moves.is_empty() and app.variation.turn == "han", "variation undo")
	app.resume_review()
	check(app.variation.is_empty() and app.review.moves.size() == 1, "resume original review point")
	app.show_review(2)
	await wait_idle()
	check(app.review.fen == live_fen, "last review position")
	app.return_live()
	check(app.review.is_empty() and not app.squares["a4"].disabled, "return to live")
	app.act("undo")
	await wait_idle()
	check(app.state.moves.size() == 0, "undo full human turn")
	app.act("move", {"move": "a1a10"})
	await wait_idle()
	check(app.state.moves.size() == 0 and app.message.text != "", "illegal move rejection")
	app.act("reset", {"mode": "ai", "humanSide": "han"})
	await wait_idle()
	for attempt in range(100):
		if app.state.moves.size() == 1:
			break
		await create_timer(0.1).timeout
		app.request_state()
		await wait_idle()
	check(app.state.moves.size() == 1 and app.state.turn == "han", "AI opening for human Han")
	check(app.grid.get_child(0).tooltip_text == "i1", "Han board orientation")
	app.endpoint.text = "http://127.0.0.1:1"
	app.request_state()
	await wait_idle()
	check(app.message.text.contains("연결"), "connection failure feedback")
	print("GODOT_SMOKE_OK")
	quit()
