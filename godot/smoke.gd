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
