extends Control

const LocalEngine = preload("res://local_engine.gd")
const EvaluationGraph = preload("res://evaluation_graph.gd")

var state: Dictionary = {}
var selected := ""
var pending := false
var api := HTTPRequest.new()
var endpoint := LineEdit.new()
var status := Label.new()
var message := Label.new()
var score_panel := Label.new()
var review_summary := Label.new()
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
var review_analysis_button := Button.new()
var review_analysis: Dictionary = {}
var analysis_preview: Dictionary = {}
var analysis_move := ""
var analysis_stage := 0
var analysis_generation := 0
var variation: Dictionary = {}
var variation_start_ply := -1
var variation_moves: Array = []
var variation_start := Button.new()
var variation_undo := Button.new()
var variation_resume := Button.new()
var variation_evaluation: Dictionary = {}
var variation_evaluation_target := ""
var full_review: Dictionary = {}
var full_review_start := Button.new()
var full_review_cancel := Button.new()
var evaluation_graph = EvaluationGraph.new()
var next_key_move_button := Button.new()
var retry_button := Button.new()
var retry_mode := false
var retry_review_ply := -1
var retry_expected_move := ""
var retry_hint_button := Button.new()
var retry_hint_stage := 0
var prediction_button := Button.new()
var prediction_index := -1
var prediction_generation := 0
var device_engine = LocalEngine.new()
var device_recommend := Button.new()
var device_cancel := Button.new()
var device_request: Dictionary = {}
var recommended_move := ""
var page_scroll := ScrollContainer.new()

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	add_child(margin)
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	page_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(page_scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.add_child(column)
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
	score_panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(score_panel)
	evaluation_graph.ply_selected.connect(show_review)
	column.add_child(evaluation_graph)
	review_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(review_summary)
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
	full_review_start.text = "전체 리뷰"
	full_review_start.custom_minimum_size.y = 44
	full_review_start.pressed.connect(start_full_review)
	actions.add_child(full_review_start)
	full_review_cancel.text = "리뷰 취소"
	full_review_cancel.custom_minimum_size.y = 44
	full_review_cancel.pressed.connect(cancel_full_review)
	actions.add_child(full_review_cancel)
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
	review_analysis_button.text = "선택 수 서버 분석"
	review_analysis_button.custom_minimum_size.y = 44
	review_analysis_button.pressed.connect(start_review_analysis)
	navigation.add_child(review_analysis_button)
	variation_start.text = "자유 분석"
	variation_start.custom_minimum_size.y = 44
	variation_start.pressed.connect(start_variation)
	navigation.add_child(variation_start)
	variation_undo.text = "분기 무르기"
	variation_undo.custom_minimum_size.y = 44
	variation_undo.pressed.connect(undo_variation)
	navigation.add_child(variation_undo)
	variation_resume.text = "재개"
	variation_resume.custom_minimum_size.y = 44
	variation_resume.pressed.connect(resume_review)
	navigation.add_child(variation_resume)
	next_key_move_button.text = "다음 핵심 수"
	next_key_move_button.custom_minimum_size.y = 44
	next_key_move_button.pressed.connect(next_key_move)
	navigation.add_child(next_key_move_button)
	retry_button.text = "다시 두기"
	retry_button.custom_minimum_size.y = 44
	retry_button.pressed.connect(start_retry)
	navigation.add_child(retry_button)
	retry_hint_button.text = "힌트"
	retry_hint_button.custom_minimum_size.y = 44
	retry_hint_button.pressed.connect(show_retry_hint)
	navigation.add_child(retry_hint_button)
	prediction_button.text = "예상 수순"
	prediction_button.custom_minimum_size.y = 44
	prediction_button.pressed.connect(play_prediction)
	navigation.add_child(prediction_button)
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
		if full_review.get("status", "") == "running":
			send("review-status", {"revision": state.revision, "jobId": full_review.jobId})
		else:
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
	if current_path == "review-analysis":
		if not payload.has("recommendedMove") or not payload.has("beforeFen") or not payload.has("recommendedFen") or not payload.get("analysis") is Dictionary:
			message.text = "복기 분석 응답 형식이 올바르지 않습니다."
		else:
			review_analysis = payload
			message.text = format_review_analysis(payload)
			play_review_analysis(payload)
		render_board()
		return
	if current_path == "variation":
		if not payload.get("variation") is Dictionary or not payload.has("fen") or not payload.has("legalMoves"):
			message.text = "자유 분석 응답 형식이 올바르지 않습니다."
		else:
			variation = payload
			variation_moves = payload.variation.moves.duplicate()
			selected = ""
			if retry_mode and variation_moves.size() == 1:
				message.text = "다시 두기 성공 · 최선 수를 찾았습니다." if variation_moves[0] == retry_expected_move else "다시 시도해 보세요 · 더 좋은 수가 있습니다."
			elif retry_mode:
				message.text = "다시 두기 · 이 장면에서 더 좋은 수를 찾아보세요."
			else:
				message.text = "자유 분석 중 · 초와 한을 번갈아 둘 수 있습니다."
			schedule_variation_evaluation()
		render_board()
		return
	if current_path in ["review-start", "review-status", "review-cancel"]:
		if not payload.has("jobId") or not payload.has("status") or not payload.has("completed") or not payload.has("total"):
			message.text = "전체 리뷰 응답 형식이 올바르지 않습니다."
		else:
			full_review = payload
			if payload.status == "running":
				message.text = "전체 리뷰 분석 중 · %d/%d수" % [int(payload.completed), int(payload.total)]
			elif payload.status == "complete":
				message.text = "전체 리뷰 완료 · %d수" % int(payload.total)
				evaluation_graph.set_results(payload.results)
				review_summary.text = format_review_summary(payload.get("summary", {}))
			elif payload.status == "cancelled":
				message.text = "전체 리뷰를 취소했습니다."
			else:
				message.text = "전체 리뷰 실패: %s" % str(payload.get("error", "알 수 없는 오류"))
		render_board()
		return
	if not payload.has("fen") or not payload.has("legalMoves"):
		message.text = "장기 서버 응답이 아닙니다."
		return
	if current_path == "review":
		cancel_device_recommendation(false)
		review = payload
		selected = ""
		var cached := cached_review_result(payload.moves.size())
		if cached.is_empty():
			message.text = "복기 중에는 착수할 수 없습니다. 현재 대국으로 돌아오세요."
		else:
			review_analysis = cached
			message.text = format_review_analysis(cached)
		render_board()
		return
	var changed: bool = state.is_empty() or payload.revision != state.revision or payload.fen != state.fen
	state = payload
	if changed:
		cancel_device_recommendation(false)
		review = {}
		clear_review_analysis()
		clear_variation()
		if not full_review.is_empty() and full_review.get("revision") != payload.revision:
			full_review = {}
			evaluation_graph.set_results([])
			review_summary.text = ""
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

func start_full_review() -> void:
	if pending or state.is_empty() or state.moves.is_empty() or full_review.get("status", "") == "running":
		return
	return_live()
	send("review-start", {"revision": state.revision})

func cancel_full_review() -> void:
	if pending or full_review.get("status", "") != "running":
		return
	send("review-cancel", {"revision": state.revision, "jobId": full_review.jobId})

func view_ply() -> int:
	return review.moves.size() if not review.is_empty() else state.get("moves", []).size()

func show_review(ply: int) -> void:
	if pending or state.is_empty() or not variation.is_empty() or ply < 0 or ply > state.moves.size():
		return
	cancel_device_recommendation(false)
	clear_review_analysis()
	selected = ""
	send("review", {"revision": state.revision, "ply": ply})

func return_live() -> void:
	if pending:
		return
	cancel_device_recommendation(false)
	review = {}
	clear_review_analysis()
	clear_variation()
	selected = ""
	message.text = ""
	render_board()

func start_variation() -> void:
	if pending or review.is_empty() or not variation.is_empty():
		return
	retry_mode = false
	retry_review_ply = -1
	retry_expected_move = ""
	retry_hint_stage = 0
	start_variation_at(view_ply())

func start_variation_at(base_ply: int) -> void:
	cancel_device_recommendation(false)
	clear_review_analysis()
	variation_start_ply = base_ply
	variation_moves = []
	send("variation", {"revision": state.revision, "basePly": variation_start_ply, "moves": variation_moves})

func start_retry() -> void:
	if pending or review.is_empty() or not variation.is_empty() or view_ply() < 1:
		return
	var cached := cached_review_result(view_ply())
	if cached.is_empty():
		return
	retry_mode = true
	retry_review_ply = view_ply()
	retry_expected_move = str(cached.recommendedMove)
	retry_hint_stage = 0
	start_variation_at(retry_review_ply - 1)

func show_retry_hint() -> void:
	if pending or not retry_mode or variation.is_empty() or not variation_moves.is_empty() or retry_hint_stage >= 2:
		return
	retry_hint_stage += 1
	message.text = "힌트 · 움직일 기물을 표시했습니다." if retry_hint_stage == 1 else "힌트 · 도착 칸까지 표시했습니다."
	render_board()

func play_variation_move(move: String) -> void:
	if pending or variation.is_empty() or not variation.legalMoves.has(move):
		return
	var next_moves := variation_moves.duplicate()
	next_moves.append(move)
	send("variation", {"revision": state.revision, "basePly": variation_start_ply, "moves": next_moves})

func undo_variation() -> void:
	if pending or variation.is_empty() or variation_moves.is_empty():
		return
	var next_moves := variation_moves.duplicate()
	next_moves.pop_back()
	send("variation", {"revision": state.revision, "basePly": variation_start_ply, "moves": next_moves})

func resume_review() -> void:
	if pending or variation.is_empty():
		return
	cancel_device_recommendation(false)
	clear_variation()
	retry_mode = false
	retry_review_ply = -1
	retry_expected_move = ""
	retry_hint_stage = 0
	selected = ""
	message.text = "복기를 재개했습니다."
	render_board()

func clear_variation() -> void:
	variation_evaluation_target = ""
	variation_evaluation = {}
	variation = {}
	variation_start_ply = -1
	variation_moves = []

func schedule_variation_evaluation() -> void:
	variation_evaluation = {}
	variation_evaluation_target = str(variation.get("fen", ""))
	if variation.get("outcome", {}).get("over", false):
		variation_evaluation_target = ""
		return
	if device_engine.busy():
		device_engine.cancel()
		return
	start_variation_evaluation()

func start_variation_evaluation() -> void:
	if variation.is_empty() or variation_evaluation_target == "" or not device_engine.available() or device_engine.busy():
		return
	device_request = {"purpose": "variation-evaluation", "revision": state.revision, "fen": variation.fen}
	if not device_engine.start(str(variation.initialFen), PackedStringArray(variation.moves)):
		device_request = {}

func start_review_analysis() -> void:
	if pending or review.is_empty() or view_ply() < 1:
		return
	var cached := cached_review_result(view_ply())
	if not cached.is_empty():
		clear_review_analysis()
		review_analysis = cached
		message.text = format_review_analysis(cached)
		play_review_analysis(cached)
		return
	clear_review_analysis()
	message.text = "%d수 서버 분석 중…" % view_ply()
	send("review-analysis", {"revision": state.revision, "ply": view_ply()})

func cached_review_result(ply: int) -> Dictionary:
	if full_review.get("status", "") != "complete":
		return {}
	for item in full_review.get("results", []):
		if int(item.get("ply", -1)) == ply:
			return item
	return {}

func format_review_summary(summary: Dictionary) -> String:
	if summary.is_empty() or int(summary.get("total", 0)) == 0:
		return ""
	var counts: Dictionary = summary.get("counts", {})
	var text := "리뷰 요약 · 최선 %d · 매우 좋음 %d · 좋음 %d · 부정확 %d · 실수 %d · 큰 실수 %d" % [
		int(counts.get("best", 0)), int(counts.get("excellent", 0)), int(counts.get("good", 0)),
		int(counts.get("inaccuracy", 0)), int(counts.get("mistake", 0)), int(counts.get("blunder", 0)),
	]
	if summary.get("averageLossCp") != null:
		text += " · 평균 손실 %dcp" % int(summary.averageLossCp)
	return text

func next_key_ply(after_ply: int) -> int:
	if full_review.get("status", "") != "complete":
		return -1
	for item in full_review.get("results", []):
		var key := str(item.get("classification", {}).get("key", ""))
		if int(item.get("ply", -1)) > after_ply and key in ["inaccuracy", "mistake", "blunder"]:
			return int(item.ply)
	return -1

func next_key_move() -> void:
	if pending or review.is_empty() or not variation.is_empty():
		return
	var ply := next_key_ply(view_ply())
	if ply >= 0:
		show_review(ply)

func clear_review_analysis() -> void:
	analysis_generation += 1
	prediction_generation += 1
	prediction_index = -1
	review_analysis = {}
	analysis_preview = {}
	analysis_move = ""
	analysis_stage = 0

func play_prediction() -> void:
	if pending or review.is_empty() or not variation.is_empty() or review_analysis.is_empty():
		return
	var fens: Array = review_analysis.get("prediction", {}).get("fens", [])
	if fens.size() < 2:
		return
	prediction_generation += 1
	var generation := prediction_generation
	analysis_generation += 1
	analysis_move = ""
	analysis_stage = 0
	for index in range(fens.size()):
		if generation != prediction_generation or review.is_empty() or not variation.is_empty():
			return
		var preview := review.duplicate(true)
		preview["fen"] = fens[index]
		preview["legalMoves"] = []
		preview["outcome"] = {"over": false, "result": "*", "winner": null, "reason": null}
		analysis_preview = preview
		prediction_index = index
		message.text = "엔진 예상 수순 재생 · %d/%d" % [index, fens.size() - 1]
		render_board()
		if index < fens.size() - 1:
			await get_tree().create_timer(0.55).timeout

func play_review_analysis(payload: Dictionary) -> void:
	analysis_generation += 1
	var generation := analysis_generation
	var preview := review.duplicate(true)
	preview["fen"] = payload.beforeFen
	preview["turn"] = payload.side
	preview["moves"] = state.moves.slice(0, int(payload.ply) - 1)
	preview["legalMoves"] = []
	preview["outcome"] = {"over": false, "result": "*", "winner": null, "reason": null}
	analysis_preview = preview
	analysis_move = str(payload.recommendedMove)
	analysis_stage = 1
	render_board()
	await get_tree().create_timer(0.45).timeout
	if generation != analysis_generation or review.is_empty():
		return
	analysis_preview["fen"] = payload.recommendedFen
	analysis_preview["moves"] = state.moves.slice(0, int(payload.ply) - 1)
	analysis_preview.moves.append(payload.recommendedMove)
	analysis_stage = 2
	render_board()

func format_evaluation(value: Variant) -> String:
	if not value is Dictionary:
		return "없음"
	var evaluation: Dictionary = value.get("evaluation", {})
	if evaluation.get("unit", "") == "cp":
		var score := int(evaluation.get("cho", 0))
		return ("+%dcp" if score >= 0 else "%dcp") % score
	if evaluation.get("unit", "") == "mate":
		return "강제승패 %s" % str(evaluation.get("cho", 0))
	return "없음"

func format_review_analysis(payload: Dictionary) -> String:
	var analysis: Dictionary = payload.analysis
	var classification: Dictionary = payload.get("classification", {})
	var result := "%d수 · 실험 등급 %s · 서버 추천 · 전 %s / 실제 수 후 %s" % [
		int(payload.ply), str(classification.get("label", "분류 제외")),
		format_evaluation(analysis.get("before")), format_evaluation(analysis.get("after")),
	]
	if analysis.get("lossCp") != null:
		return result + " · 손실 %dcp" % int(analysis.lossCp)
	var reasons := {"terminal": "대국 종료", "mate-score": "강제승패 평가", "analysis-unavailable": "평가 없음"}
	return result + " · 손실 계산 제외(%s)" % str(reasons.get(analysis.get("lossReason", ""), "사유 미확인"))

func split_move(move: String) -> PackedStringArray:
	var regex := RegEx.new()
	regex.compile("^([a-i](?:10|[1-9]))([a-i](?:10|[1-9]))$")
	var found := regex.search(move)
	return PackedStringArray([found.get_string(1), found.get_string(2)]) if found else PackedStringArray()

func pass_turn() -> void:
	var position: Dictionary = variation if not variation.is_empty() else state
	for move in position.get("legalMoves", []):
		var pair := split_move(move)
		if pair.size() == 2 and pair[0] == pair[1]:
			if variation.is_empty():
				act("move", {"move": move})
			else:
				play_variation_move(move)
			return

func choose(square: String, piece: String) -> void:
	if pending or (not review.is_empty() and variation.is_empty()):
		return
	var position: Dictionary = variation if not variation.is_empty() else state
	if selected != "" and selected != square and position.legalMoves.has(selected + square):
		if variation.is_empty():
			act("move", {"move": selected + square})
		else:
			play_variation_move(selected + square)
		return
	var own: bool = piece != "" and ((piece == piece.to_upper()) == (position.turn == "cho"))
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
	if expected.get("purpose", "") == "variation-evaluation":
		if not result.has("error") and not variation.is_empty() and state.revision == expected.revision and variation.fen == expected.fen and result.get("fen", "") == variation.fen:
			variation_evaluation = {
				"unit": str(result.get("evaluation_unit", "")), "cho": int(result.get("evaluation_cho", 0)),
				"depth": int(result.get("depth", 0)), "elapsedMs": int(result.get("elapsed_ms", 0)),
			}
		if not variation.is_empty() and variation_evaluation_target != "" and variation.fen != expected.get("fen", ""):
			call_deferred("start_variation_evaluation")
		render_board()
		return
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
	var position: Dictionary = variation if not variation.is_empty() else (analysis_preview if not analysis_preview.is_empty() else (state if review.is_empty() else review))
	render_position(position)

func render_position(state: Dictionary) -> void:
	history.disabled = pending or self.state.is_empty()
	for button in review_buttons:
		button.disabled = pending or self.state.is_empty()
	review_analysis_button.disabled = pending or review.is_empty() or view_ply() < 1
	if state.is_empty():
		score_panel.text = ""
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
	var ai_turn: bool = variation.is_empty() and state.mode == "ai" and state.turn != state.humanSide
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
			var review_recommendation := split_move(analysis_move)
			if review_recommendation.size() == 2 and square == review_recommendation[0]:
				button.modulate = Color(1, 0.78, 0.2)
			elif review_recommendation.size() == 2 and analysis_stage == 2 and square == review_recommendation[1]:
				button.modulate = Color(0.35, 1, 0.55)
			var retry_hint := split_move(retry_expected_move)
			if retry_mode and retry_hint.size() == 2 and retry_hint_stage >= 1 and square == retry_hint[0]:
				button.modulate = Color(1, 0.78, 0.2)
			elif retry_mode and retry_hint.size() == 2 and retry_hint_stage >= 2 and square == retry_hint[1]:
				button.modulate = Color(0.35, 1, 0.55)
			button.disabled = (not review.is_empty() and variation.is_empty()) or (pending and current_path != "game") or ai_turn or state.outcome.over
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
	var points: Dictionary = state.get("points", {})
	var cho_points := float(points.get("cho", 0.0))
	var han_points := float(points.get("han", 0.0))
	score_panel.text = "기물 점수 · 초 %.1f / 한 %.1f · 차이 %+.1f" % [cho_points, han_points, cho_points - han_points]
	if not variation.is_empty():
		if variation_evaluation.is_empty():
			score_panel.text += " · 기기 형세 계산 중…" if device_engine.available() else " · 기기 형세 사용 불가"
		elif variation_evaluation.unit == "cp":
			score_panel.text += " · 기기 고전평가 초 %+.0fcp · 깊이 %d" % [float(variation_evaluation.cho), int(variation_evaluation.depth)]
		else:
			score_panel.text += " · 기기 고전평가 강제승패 %s" % str(variation_evaluation.cho)
	for button in action_buttons:
		button.disabled = not review.is_empty() or (pending and current_path != "game")
	action_buttons[1].disabled = action_buttons[1].disabled or ai_turn or state.outcome.over or state.inCheck
	action_buttons[2].disabled = action_buttons[2].disabled or not state.canUndo
	action_buttons[3].disabled = action_buttons[3].disabled or state.ai.status != "thinking"
	action_buttons[4].disabled = action_buttons[4].disabled or not state.ai.status in ["paused", "error"]
	device_recommend.disabled = not variation.is_empty() or not device_engine.available() or device_engine.busy() or state.outcome.over or state.legalMoves.is_empty()
	device_cancel.disabled = not variation.is_empty() or not device_engine.busy()
	full_review_start.disabled = pending or self.state.moves.is_empty() or full_review.get("status", "") == "running"
	full_review_cancel.disabled = pending or full_review.get("status", "") != "running"
	if not review.is_empty():
		status.text = "복기 %d/%d수 · %s" % [view_ply(), self.state.moves.size(), status.text]
	if not analysis_preview.is_empty():
		status.text = "서버 추천 수 재생 · " + status.text
	history.clear()
	history.add_item("0수 · 시작 배치")
	for index in range(self.state.moves.size()):
		var pair := split_move(self.state.moves[index])
		var description: String = "한수쉼" if pair[0] == pair[1] else "%s → %s" % [pair[0], pair[1]]
		history.add_item("%d수 · %s %s" % [index + 1, "초" if index % 2 == 0 else "한", description])
	history.select(view_ply())
	evaluation_graph.select_ply(view_ply())
	review_buttons[0].disabled = pending or self.state.moves.is_empty()
	review_buttons[1].disabled = pending or view_ply() == 0
	review_buttons[2].disabled = pending or review.is_empty() or view_ply() >= self.state.moves.size()
	review_buttons[3].disabled = pending or review.is_empty()
	review_analysis_button.disabled = pending or review.is_empty() or view_ply() < 1
	for button in review_buttons:
		button.disabled = button.disabled or not variation.is_empty()
	review_analysis_button.disabled = review_analysis_button.disabled or not variation.is_empty()
	variation_start.disabled = pending or review.is_empty() or not variation.is_empty()
	variation_undo.disabled = pending or variation.is_empty() or variation_moves.is_empty()
	variation_resume.disabled = pending or variation.is_empty()
	next_key_move_button.disabled = pending or review.is_empty() or not variation.is_empty() or next_key_ply(view_ply()) < 0
	retry_button.disabled = pending or review.is_empty() or not variation.is_empty() or view_ply() < 1 or cached_review_result(view_ply()).is_empty()
	retry_hint_button.disabled = pending or not retry_mode or variation.is_empty() or not variation_moves.is_empty() or retry_hint_stage >= 2
	prediction_button.disabled = pending or review.is_empty() or not variation.is_empty() or review_analysis.get("prediction", {}).get("fens", []).size() < 2
