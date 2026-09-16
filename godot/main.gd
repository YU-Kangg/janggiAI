extends Control

const LocalEngine = preload("res://local_engine.gd")

var state: Dictionary = {}
var selected := ""
var pending := false
var api := HTTPRequest.new()
var endpoint := LineEdit.new()
var status := Label.new()
var message := Label.new()
var grid := GridContainer.new()
var side := OptionButton.new()
var action_buttons: Array[Button] = []
var squares: Dictionary = {}
var timer := Timer.new()
var new_game_dialog := ConfirmationDialog.new()
var current_path := ""
var review: Dictionary = {}
var history := OptionButton.new()
var review_buttons: Array[Button] = []
var device_engine = LocalEngine.new()
var device_recommend := Button.new()
var device_cancel := Button.new()
var device_request: Dictionary = {}
var recommended_move := ""

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var title := Label.new()
	title.text = "고양이 장기 · 플레이 시제품"
	column.add_child(title)
	endpoint.text = "http://127.0.0.1:3000"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--server="):
			endpoint.text = arg.trim_prefix("--server=")
	column.add_child(endpoint)
	var connect_button := Button.new()
	connect_button.text = "서버 연결 / 다시 시도"
	connect_button.pressed.connect(func(): request_state())
	column.add_child(connect_button)
	status.text = "서버에 연결 중…"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	side.add_item("초로 AI 대국")
	side.add_item("한으로 AI 대국")
	column.add_child(side)
	grid.columns = 9
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(grid)
	var actions := HFlowContainer.new()
	column.add_child(actions)
	add_action(actions, "새 AI 대국", func(): new_game_dialog.popup_centered())
	add_action(actions, "한수쉼", pass_turn)
	add_action(actions, "무르기", func(): act("undo"))
	add_action(actions, "AI 취소", func(): act("cancel-ai"))
	add_action(actions, "AI 재개", func(): act("resume-ai"))
	device_recommend.text = "기기 추천"
	device_recommend.custom_minimum_size.y = 44
	device_recommend.pressed.connect(start_device_recommendation)
	actions.add_child(device_recommend)
	device_cancel.text = "추천 취소"
	device_cancel.custom_minimum_size.y = 44
	device_cancel.pressed.connect(cancel_device_recommendation)
	actions.add_child(device_cancel)
	device_engine.completed.connect(on_device_recommendation)
	column.add_child(history)
	history.item_selected.connect(func(index: int): show_review(index))
	var navigation := HFlowContainer.new()
	column.add_child(navigation)
	for caption in ["처음", "이전 수", "다음 수", "현재 대국"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size.y = 44
		navigation.add_child(button)
		review_buttons.append(button)
	review_buttons[0].pressed.connect(func(): show_review(0))
	review_buttons[1].pressed.connect(func(): show_review(view_ply() - 1))
	review_buttons[2].pressed.connect(func(): show_review(view_ply() + 1))
	review_buttons[3].pressed.connect(return_live)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message)
	new_game_dialog.dialog_text = "공유 중인 현재 대국을 지우고 새 AI 대국을 시작할까요?"
	new_game_dialog.confirmed.connect(func(): act("reset", {"mode": "ai", "humanSide": "cho" if side.selected == 0 else "han"}))
	add_child(new_game_dialog)
	api.timeout = 8.0
	api.request_completed.connect(on_response)
	add_child(api)
	timer.wait_time = 0.5
	timer.timeout.connect(request_state)
	add_child(timer)
	timer.start()
	render_board()
	request_state()

func _exit_tree() -> void:
	device_engine.shutdown()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		cancel_device_recommendation()

func add_action(parent: Node, caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	parent.add_child(button)
	action_buttons.append(button)

func request_state() -> void:
	if not pending:
		send("game")

func send(path: String, data: Dictionary = {}) -> void:
	if pending:
		return
	var url := endpoint.text.strip_edges().trim_suffix("/")
	if not (url.begins_with("http://") or url.begins_with("https://")):
		message.text = "http:// 또는 https:// 서버 주소를 입력하세요."
		return
	pending = true
	current_path = path
	endpoint.editable = false
	var method := HTTPClient.METHOD_GET if path == "game" else HTTPClient.METHOD_POST
	var error := api.request(url + "/api/" + path, ["Content-Type: application/json"], method, "" if path == "game" else JSON.stringify(data))
	if path != "game":
		render_board()
	if error != OK:
		pending = false
		endpoint.editable = true
		message.text = "연결 요청 실패: %s" % error
		render_board()

func on_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	pending = false
	endpoint.editable = true
	var parser := JSON.new()
	if result != HTTPRequest.RESULT_SUCCESS or parser.parse(body.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		message.text = "서버에 연결하지 못했습니다. 서버 실행과 주소를 확인하세요."
		render_board()
		return
	var payload: Dictionary = parser.data
	if code != 200:
		message.text = str(payload.get("error", "요청 실패"))
		selected = ""
		render_board()
		return
	if not payload.has("fen") or not payload.has("legalMoves"):
		message.text = "장기 서버 응답이 아닙니다."
		return
	if current_path == "review":
		cancel_device_recommendation(false)
		review = payload
		selected = ""
		message.text = "복기 중에는 착수할 수 없습니다. 현재 대국으로 돌아오세요."
		render_board()
		return
	var changed: bool = state.is_empty() or payload.revision != state.revision or payload.fen != state.fen
	state = payload
	if changed:
		cancel_device_recommendation(false)
		review = {}
		selected = ""
	if current_path != "game" or changed:
		message.text = ""
	if changed or current_path != "game":
		render_board()

func act(action: String, data: Dictionary = {}) -> void:
	if state.is_empty() or pending or not review.is_empty():
		return
	cancel_device_recommendation(false)
	data["revision"] = state.revision
	send(action, data)

func view_ply() -> int:
	return review.moves.size() if not review.is_empty() else state.get("moves", []).size()

func show_review(ply: int) -> void:
	if pending or state.is_empty() or ply < 0 or ply > state.moves.size():
		return
	cancel_device_recommendation(false)
	selected = ""
	send("review", {"revision": state.revision, "ply": ply})

func return_live() -> void:
	if pending:
		return
	cancel_device_recommendation(false)
	review = {}
	selected = ""
	message.text = ""
	render_board()

func split_move(move: String) -> PackedStringArray:
	var regex := RegEx.new()
	regex.compile("^([a-i](?:10|[1-9]))([a-i](?:10|[1-9]))$")
	var found := regex.search(move)
	return PackedStringArray([found.get_string(1), found.get_string(2)]) if found else PackedStringArray()

func pass_turn() -> void:
	for move in state.get("legalMoves", []):
		var pair := split_move(move)
		if pair.size() == 2 and pair[0] == pair[1]:
			act("move", {"move": move})
			return

func choose(square: String, piece: String) -> void:
	if pending or not review.is_empty():
		return
	if selected != "" and selected != square and state.legalMoves.has(selected + square):
		act("move", {"move": selected + square})
		return
	var own: bool = piece != "" and ((piece == piece.to_upper()) == (state.turn == "cho"))
	selected = square if own and selected != square else ""
	render_board()

func start_device_recommendation() -> void:
	var position: Dictionary = state if review.is_empty() else review
	if position.is_empty() or position.outcome.over or position.legalMoves.is_empty() or device_engine.busy():
		return
	recommended_move = ""
	device_request = {"revision": state.revision, "fen": position.fen}
	var moves := PackedStringArray(position.moves)
	if not device_engine.start(str(position.initialFen), moves):
		message.text = "이 기기에서는 추천 엔진을 시작할 수 없습니다."
		device_request = {}
	else:
		message.text = "휴대폰에서 추천 수를 계산 중…"
	render_board()

func cancel_device_recommendation(show_message := true) -> void:
	if device_engine.busy():
		device_engine.cancel()
		if show_message:
			message.text = "기기 추천을 취소했습니다."
	device_request = {}
	recommended_move = ""

func on_device_recommendation(result: Dictionary) -> void:
	var position: Dictionary = state if review.is_empty() else review
	var expected := device_request
	device_request = {}
	if expected.is_empty():
		render_board()
		return
	var move := str(result.get("move", ""))
	if result.has("error"):
		message.text = "기기 추천 실패: %s" % str(result.error)
	elif state.revision != expected.revision or position.fen != expected.fen:
		message.text = "대국 상태가 바뀌어 이전 추천을 버렸습니다."
	elif result.get("fen", "") != position.fen or not position.legalMoves.has(move):
		message.text = "기기 엔진의 결과가 현재 장기판과 맞지 않습니다."
	else:
		recommended_move = move
		var pair := split_move(move)
		message.text = "기기 추천 %s → %s · 깊이 %d · %dms" % [pair[0], pair[1], int(result.get("depth", 0)), int(result.get("elapsed_ms", 0))]
		print("JANGGI_NATIVE_RESULT move=%s depth=%d elapsed_ms=%d" % [move, int(result.get("depth", 0)), int(result.get("elapsed_ms", 0))])
	render_board()

func render_board() -> void:
	render_position(state if review.is_empty() else review)

func render_position(state: Dictionary) -> void:
	history.disabled = pending or self.state.is_empty()
	for button in review_buttons:
		button.disabled = pending or self.state.is_empty()
	if state.is_empty():
		for button in action_buttons:
			button.disabled = true
		device_recommend.disabled = true
		device_cancel.disabled = true
		return
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	squares.clear()
	var pieces: Dictionary = {}
	var rows: PackedStringArray = str(state.fen).split(" ")[0].split("/")
	for row in range(10):
		var file := 0
		for token in rows[row]:
			if token.is_valid_int():
				file += int(token)
			else:
				pieces[String.chr(97 + file) + str(10 - row)] = token
				file += 1
	var ai_turn: bool = state.mode == "ai" and state.turn != state.humanSide
	var flipped: bool = state.mode == "ai" and state.humanSide == "han"
	var labels := {"k": "궁", "a": "사", "r": "차", "n": "마", "b": "상", "c": "포", "p": "졸"}
	for row in range(10):
		for file in range(9):
			var square := String.chr(97 + (8 - file if flipped else file)) + str(row + 1 if flipped else 10 - row)
			var piece: String = pieces.get(square, "")
			var button := Button.new()
			button.text = ("병" if piece == "p" else str(labels.get(piece.to_lower(), "·")))
			button.tooltip_text = square
			button.custom_minimum_size = Vector2(40, 42)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.size_flags_vertical = Control.SIZE_EXPAND_FILL
			button.modulate = Color(0.55, 0.8, 1) if piece != "" and piece == piece.to_upper() else Color(1, 0.7, 0.65)
			if square == selected or (selected != "" and state.legalMoves.has(selected + square)):
				button.modulate = Color(0.7, 1, 0.5)
			var recommendation := split_move(recommended_move)
			if recommendation.size() == 2 and square == recommendation[0]:
				button.modulate = Color(1, 0.85, 0.35)
			elif recommendation.size() == 2 and square == recommendation[1]:
				button.modulate = Color(0.45, 1, 0.65)
			button.disabled = not review.is_empty() or (pending and current_path != "game") or ai_turn or state.outcome.over
			button.pressed.connect(choose.bind(square, piece))
			grid.add_child(button)
			squares[square] = button
	status.text = "%s 차례 · %d수 · AI %s" % ["초" if state.turn == "cho" else "한", state.moves.size(), state.ai.status]
	if state.inCheck:
		status.text += " · 장군"
	if state.outcome.over:
		status.text = "대국 종료: %s · %s" % [state.outcome.result, state.outcome.reason]
	if state.ai.status == "error":
		status.text += " · " + str(state.ai.error)
	for button in action_buttons:
		button.disabled = not review.is_empty() or (pending and current_path != "game")
	action_buttons[1].disabled = action_buttons[1].disabled or ai_turn or state.outcome.over or state.inCheck
	action_buttons[2].disabled = action_buttons[2].disabled or not state.canUndo
	action_buttons[3].disabled = action_buttons[3].disabled or state.ai.status != "thinking"
	action_buttons[4].disabled = action_buttons[4].disabled or not state.ai.status in ["paused", "error"]
	device_recommend.disabled = not device_engine.available() or device_engine.busy() or state.outcome.over or state.legalMoves.is_empty()
	device_cancel.disabled = not device_engine.busy()
	if not review.is_empty():
		status.text = "복기 %d/%d수 · %s" % [view_ply(), self.state.moves.size(), status.text]
	history.clear()
	history.add_item("0수 · 시작 배치")
	for index in range(self.state.moves.size()):
		var pair := split_move(self.state.moves[index])
		var description: String = "한수쉼" if pair[0] == pair[1] else "%s → %s" % [pair[0], pair[1]]
		history.add_item("%d수 · %s %s" % [index + 1, "초" if index % 2 == 0 else "한", description])
	history.select(view_ply())
	review_buttons[0].disabled = pending or self.state.moves.is_empty()
	review_buttons[1].disabled = pending or view_ply() == 0
	review_buttons[2].disabled = pending or review.is_empty() or view_ply() >= self.state.moves.size()
	review_buttons[3].disabled = pending or review.is_empty()
