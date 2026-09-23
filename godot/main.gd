extends Control

const LocalEngine = preload("res://local_engine.gd")
const EvaluationGraph = preload("res://evaluation_graph.gd")
const SETUPS := ["nbbn", "bnbn", "nbnb", "bnnb"]

var state: Dictionary = {}
var selected := ""
var pending := false
var api := HTTPRequest.new()
var endpoint := LineEdit.new()
var status := Label.new()
var message := Label.new()
var score_panel := Label.new()
var review_summary := Label.new()
var review_method_notice := Label.new()
var key_move_status := Label.new()
var grid := GridContainer.new()
var side := OptionButton.new()
var cho_setup := OptionButton.new()
var han_setup := OptionButton.new()
var time_control := OptionButton.new()
var cho_name := LineEdit.new()
var han_name := LineEdit.new()
var clock_panel := Label.new()
var game_mode_tabs := TabContainer.new()
var ai_game_panel := VBoxContainer.new()
var local_game_panel := VBoxContainer.new()
var ai_setup_summary := Label.new()
var local_setup_summary := Label.new()
var setup_dialog := ConfirmationDialog.new()
var selected_cho_setup := "nbbn"
var selected_han_setup := "nbbn"
var offline_local := false
var offline_native: Object
var offline_moves: Array[String] = []
var offline_adjudication: Dictionary = {}
var offline_time_control: Variant = null
var offline_clock := {"cho": 0, "han": 0}
var offline_clock_started := 0
var offline_save_path := "user://local-match.json"
var offline_backup_path := "user://local-match.backup.json"
var pending_ai_start_after_connect := false
var pending_new_mode := "ai"
var resign_button := Button.new()
var draw_button := Button.new()
var rematch_button := Button.new()
var resign_dialog := ConfirmationDialog.new()
var draw_dialog := ConfirmationDialog.new()
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
var review_restore_revision := -1
var open_review_when_ready := false
var full_review_start := Button.new()
var full_review_cancel := Button.new()
var review_export_button := Button.new()
var review_import_button := Button.new()
var review_export_path := "user://janggi-review.json"
var evaluation_graph = EvaluationGraph.new()
var previous_key_move_button := Button.new()
var next_key_move_button := Button.new()
var worst_move_button := Button.new()
var key_move_filter := OptionButton.new()
var retry_button := Button.new()
var retry_mode := false
var retry_review_ply := -1
var retry_expected_move := ""
var retry_hint_button := Button.new()
var retry_next_button := Button.new()
var retry_hint_stage := 0
var prediction_button := Button.new()
var prediction_stop_button := Button.new()
var prediction_previous_button := Button.new()
var prediction_next_button := Button.new()
var prediction_index := -1
var prediction_generation := 0
var prediction_playing := false
var game_review_play_button := Button.new()
var game_review_stop_button := Button.new()
var game_review_generation := 0
var game_review_playing := false
var playback_speed := OptionButton.new()
var device_engine = LocalEngine.new()
var device_recommend := Button.new()
var device_cancel := Button.new()
var device_request: Dictionary = {}
var recommended_move := ""
var page_scroll := ScrollContainer.new()
var last_animated_move := ""
var piece_move_animation_seconds := 0.18
var playback_move := ""
var review_tabs := TabContainer.new()
var review_workspace := VBoxContainer.new()
var review_analysis_workspace := VBoxContainer.new()
var review_archive_workspace := VBoxContainer.new()
var review_start_controls := HFlowContainer.new()
var review_navigation_controls := HFlowContainer.new()
var review_coach_controls := HFlowContainer.new()
var review_key_controls := HFlowContainer.new()
var review_analysis_controls := HFlowContainer.new()
var review_playback_controls := HFlowContainer.new()
var review_file_controls := HFlowContainer.new()

func add_section_title(parent: Control, caption: String) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("7a5448"))
	parent.add_child(label)

func cream_box(background: Color, border := Color("ead6c5"), radius := 14, border_width := 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func create_app_theme() -> Theme:
	var app_theme := Theme.new()
	app_theme.default_font_size = 16
	app_theme.set_color("font_color", "Label", Color("62483f"))
	app_theme.set_color("font_color", "Button", Color("684a40"))
	app_theme.set_color("font_hover_color", "Button", Color("5b4038"))
	app_theme.set_color("font_pressed_color", "Button", Color("5b4038"))
	app_theme.set_color("font_focus_color", "Button", Color("5b4038"))
	app_theme.set_color("font_disabled_color", "Button", Color("aa948a"))
	app_theme.set_stylebox("normal", "Button", cream_box(Color("fff2dd")))
	app_theme.set_stylebox("hover", "Button", cream_box(Color("ffe7c2"), Color("e6bd91"), 14, 2))
	app_theme.set_stylebox("pressed", "Button", cream_box(Color("ffd9ab"), Color("dca876"), 14, 2))
	app_theme.set_stylebox("disabled", "Button", cream_box(Color("f4eadf"), Color("eadfd5")))
	for control_type in ["OptionButton", "LineEdit"]:
		app_theme.set_color("font_color", control_type, Color("62483f"))
		app_theme.set_color("font_placeholder_color", control_type, Color("aa8e82"))
		app_theme.set_stylebox("normal", control_type, cream_box(Color("fffaf2")))
		app_theme.set_stylebox("focus", control_type, cream_box(Color("fffdf8"), Color("e7b985"), 14, 2))
	app_theme.set_stylebox("panel", "TabContainer", cream_box(Color("fffaf2"), Color("edd8c4"), 16, 1))
	app_theme.set_stylebox("tab_selected", "TabContainer", cream_box(Color("ffdcae"), Color("e5b77f"), 12, 1))
	app_theme.set_stylebox("tab_unselected", "TabContainer", cream_box(Color("f9eddf"), Color("ead8c7"), 12, 1))
	app_theme.set_color("font_selected_color", "TabContainer", Color("6b493d"))
	app_theme.set_color("font_unselected_color", "TabContainer", Color("92786d"))
	app_theme.set_stylebox("panel", "PopupPanel", cream_box(Color("fffaf2"), Color("e6cbb2"), 18, 2))
	for dialog_type in ["Window", "AcceptDialog", "ConfirmationDialog"]:
		app_theme.set_stylebox("panel", dialog_type, cream_box(Color("fffaf2"), Color("e6cbb2"), 18, 2))
		app_theme.set_color("title_color", dialog_type, Color("684a40"))
	return app_theme

func board_box(background: Color) -> StyleBoxFlat:
	var box := cream_box(background, Color("e3cdb8"), 8, 1)
	box.content_margin_left = 2
	box.content_margin_right = 2
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box

func _ready() -> void:
	theme = create_app_theme()
	var background := ColorRect.new()
	background.color = Color("fff7e8")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 14)
	add_child(margin)
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	page_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(page_scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.add_child(column)
	var title := Label.new()
	title.text = "고양이 장기 · 냥이들의 한판"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("845847"))
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
	review_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	review_method_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game_mode_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(game_mode_tabs)
	ai_game_panel.name = "AI 대전"
	ai_game_panel.add_theme_constant_override("separation", 8)
	game_mode_tabs.add_child(ai_game_panel)
	var ai_description := Label.new()
	ai_description.text = "장기 엔진과 대국합니다. 플레이할 진영을 선택하세요."
	ai_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ai_game_panel.add_child(ai_description)
	side.add_item("초로 AI 대국")
	side.add_item("한으로 AI 대국")
	ai_game_panel.add_child(side)
	ai_setup_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ai_game_panel.add_child(ai_setup_summary)
	var ai_setup_button := Button.new()
	ai_setup_button.text = "기물 배치 선택"
	ai_setup_button.custom_minimum_size.y = 44
	ai_setup_button.pressed.connect(open_setup_dialog)
	ai_game_panel.add_child(ai_setup_button)
	add_action(ai_game_panel, "새 AI 대국 시작", func(): open_new_game_dialog("ai"))
	local_game_panel.name = "로컬 2인 대전"
	local_game_panel.add_theme_constant_override("separation", 8)
	game_mode_tabs.add_child(local_game_panel)
	var local_description := Label.new()
	local_description.text = "한 기기에서 초와 한이 번갈아 둡니다."
	local_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	local_game_panel.add_child(local_description)
	cho_name.placeholder_text = "초 대국자 이름"
	cho_name.text = "초"
	han_name.placeholder_text = "한 대국자 이름"
	han_name.text = "한"
	local_game_panel.add_child(cho_name)
	local_game_panel.add_child(han_name)
	for option in [cho_setup, han_setup]:
		option.add_item("마상상마")
		option.add_item("상마마상")
		option.add_item("마상마상")
		option.add_item("상마상마")
	cho_setup.select(0)
	han_setup.select(0)
	cho_setup.tooltip_text = "초 차림"
	han_setup.tooltip_text = "한 차림"
	time_control.add_item("시간 제한 없음")
	time_control.add_item("5분")
	time_control.add_item("10분 + 5초")
	time_control.add_item("30분")
	local_game_panel.add_child(time_control)
	local_setup_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	local_game_panel.add_child(local_setup_summary)
	var local_setup_button := Button.new()
	local_setup_button.text = "기물 배치 선택"
	local_setup_button.custom_minimum_size.y = 44
	local_setup_button.pressed.connect(open_setup_dialog)
	local_game_panel.add_child(local_setup_button)
	var local_game_button := Button.new()
	local_game_button.text = "새 로컬 대국 시작"
	local_game_button.custom_minimum_size.y = 44
	local_game_button.pressed.connect(func(): open_new_game_dialog("local"))
	local_game_panel.add_child(local_game_button)
	update_setup_summaries()
	clock_panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(clock_panel)
	grid.columns = 9
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(grid)
	var actions := HFlowContainer.new()
	column.add_child(actions)
	add_action(actions, "한수쉼", pass_turn)
	add_action(actions, "무르기", func(): act("undo"))
	add_action(actions, "AI 취소", func(): act("cancel-ai"))
	add_action(actions, "AI 재개", func(): act("resume-ai"))
	resign_button.text = "기권"
	resign_button.custom_minimum_size.y = 44
	resign_button.pressed.connect(func(): resign_dialog.popup_centered())
	actions.add_child(resign_button)
	draw_button.text = "합의 무승부"
	draw_button.custom_minimum_size.y = 44
	draw_button.pressed.connect(func(): draw_dialog.popup_centered())
	actions.add_child(draw_button)
	rematch_button.text = "같은 설정 재대국"
	rematch_button.custom_minimum_size.y = 44
	rematch_button.pressed.connect(func(): open_new_game_dialog(str(state.get("mode", "local"))))
	actions.add_child(rematch_button)
	device_recommend.text = "기기 추천"
	device_recommend.custom_minimum_size.y = 44
	device_recommend.pressed.connect(start_device_recommendation)
	actions.add_child(device_recommend)
	device_cancel.text = "추천 취소"
	device_cancel.custom_minimum_size.y = 44
	device_cancel.pressed.connect(cancel_device_recommendation)
	actions.add_child(device_cancel)
	full_review_start.text = "게임 리뷰 시작"
	full_review_start.custom_minimum_size.y = 44
	full_review_start.pressed.connect(start_full_review)
	full_review_cancel.text = "리뷰 취소"
	full_review_cancel.custom_minimum_size.y = 44
	full_review_cancel.pressed.connect(cancel_full_review)
	review_export_button.text = "리뷰 JSON 저장"
	review_export_button.custom_minimum_size.y = 44
	review_export_button.pressed.connect(export_full_review)
	review_import_button.text = "리뷰 JSON 불러오기"
	review_import_button.custom_minimum_size.y = 44
	review_import_button.pressed.connect(import_full_review)
	device_engine.completed.connect(on_device_recommendation)
	review_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(review_tabs)
	review_workspace.name = "게임 리뷰"
	review_workspace.add_theme_constant_override("separation", 8)
	review_workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	review_tabs.add_child(review_workspace)
	add_section_title(review_workspace, "대국 리뷰")
	review_start_controls.add_child(full_review_start)
	review_start_controls.add_child(full_review_cancel)
	review_workspace.add_child(review_start_controls)
	review_workspace.add_child(review_summary)
	review_workspace.add_child(review_method_notice)
	review_workspace.add_child(evaluation_graph)
	add_section_title(review_workspace, "현재 장면")
	review_workspace.add_child(key_move_status)
	review_workspace.add_child(history)
	history.item_selected.connect(func(index: int): show_review(index))
	review_workspace.add_child(review_navigation_controls)
	for caption in ["처음", "이전 수", "다음 수", "현재 대국"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size.y = 44
		review_navigation_controls.add_child(button)
		review_buttons.append(button)
	review_buttons[0].pressed.connect(func(): show_review(0))
	review_buttons[1].pressed.connect(func(): show_review(view_ply() - 1))
	review_buttons[2].pressed.connect(func(): show_review(view_ply() + 1))
	review_buttons[3].text = "대국으로 돌아가기"
	review_buttons[3].pressed.connect(return_live)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	review_workspace.add_child(message)
	add_section_title(review_workspace, "이 수에서 배워보기")
	review_analysis_button.text = "최선 수 보기"
	review_analysis_button.custom_minimum_size.y = 44
	review_analysis_button.pressed.connect(start_review_analysis)
	review_coach_controls.add_child(review_analysis_button)
	retry_button.text = "다시 풀기"
	retry_button.custom_minimum_size.y = 44
	retry_button.pressed.connect(start_retry)
	review_coach_controls.add_child(retry_button)
	retry_hint_button.text = "힌트"
	retry_hint_button.custom_minimum_size.y = 44
	retry_hint_button.pressed.connect(show_retry_hint)
	review_coach_controls.add_child(retry_hint_button)
	retry_next_button.text = "다음 실수"
	retry_next_button.custom_minimum_size.y = 44
	retry_next_button.pressed.connect(continue_retry_to_next_key)
	review_coach_controls.add_child(retry_next_button)
	review_workspace.add_child(review_coach_controls)
	add_section_title(review_workspace, "핵심 장면")
	previous_key_move_button.text = "이전 핵심 수"
	previous_key_move_button.custom_minimum_size.y = 44
	previous_key_move_button.pressed.connect(previous_key_move)
	review_key_controls.add_child(previous_key_move_button)
	key_move_filter.add_item("핵심: 부정확 이상")
	key_move_filter.add_item("핵심: 실수 이상")
	key_move_filter.add_item("핵심: 큰 실수만")
	key_move_filter.item_selected.connect(func(_index: int): render_board())
	review_key_controls.add_child(key_move_filter)
	next_key_move_button.text = "다음 핵심 수"
	next_key_move_button.custom_minimum_size.y = 44
	next_key_move_button.pressed.connect(next_key_move)
	review_key_controls.add_child(next_key_move_button)
	worst_move_button.text = "최대 손실 수"
	worst_move_button.custom_minimum_size.y = 44
	worst_move_button.pressed.connect(show_worst_move)
	review_key_controls.add_child(worst_move_button)
	review_workspace.add_child(review_key_controls)
	review_analysis_workspace.name = "자유 분석"
	review_analysis_workspace.add_theme_constant_override("separation", 8)
	review_tabs.add_child(review_analysis_workspace)
	add_section_title(review_analysis_workspace, "직접 수를 놓아 분석")
	variation_start.text = "자유 분석"
	variation_start.custom_minimum_size.y = 44
	variation_start.pressed.connect(start_variation)
	review_analysis_controls.add_child(variation_start)
	variation_undo.text = "분기 무르기"
	variation_undo.custom_minimum_size.y = 44
	variation_undo.pressed.connect(undo_variation)
	review_analysis_controls.add_child(variation_undo)
	variation_resume.text = "재개"
	variation_resume.custom_minimum_size.y = 44
	variation_resume.pressed.connect(resume_review)
	review_analysis_controls.add_child(variation_resume)
	prediction_button.text = "추천 수순 보기"
	prediction_button.custom_minimum_size.y = 44
	prediction_button.pressed.connect(play_prediction)
	review_analysis_controls.add_child(prediction_button)
	prediction_stop_button.text = "수순 정지"
	prediction_stop_button.custom_minimum_size.y = 44
	prediction_stop_button.pressed.connect(stop_prediction)
	review_analysis_controls.add_child(prediction_stop_button)
	prediction_previous_button.text = "수순 이전"
	prediction_previous_button.custom_minimum_size.y = 44
	prediction_previous_button.pressed.connect(func(): step_prediction(-1))
	review_analysis_controls.add_child(prediction_previous_button)
	prediction_next_button.text = "수순 다음"
	prediction_next_button.custom_minimum_size.y = 44
	prediction_next_button.pressed.connect(func(): step_prediction(1))
	review_analysis_controls.add_child(prediction_next_button)
	review_analysis_workspace.add_child(review_analysis_controls)
	add_section_title(review_workspace, "리뷰 재생")
	game_review_play_button.text = "기보 재생"
	game_review_play_button.custom_minimum_size.y = 44
	game_review_play_button.pressed.connect(play_game_review)
	review_playback_controls.add_child(game_review_play_button)
	game_review_stop_button.text = "기보 정지"
	game_review_stop_button.custom_minimum_size.y = 44
	game_review_stop_button.pressed.connect(stop_game_review)
	review_playback_controls.add_child(game_review_stop_button)
	playback_speed.add_item("재생 느리게")
	playback_speed.add_item("재생 보통")
	playback_speed.add_item("재생 빠르게")
	playback_speed.select(1)
	review_playback_controls.add_child(playback_speed)
	review_workspace.add_child(review_playback_controls)
	review_archive_workspace.name = "보관"
	review_archive_workspace.add_theme_constant_override("separation", 8)
	review_tabs.add_child(review_archive_workspace)
	add_section_title(review_archive_workspace, "리뷰 파일")
	review_file_controls.add_child(review_export_button)
	review_file_controls.add_child(review_import_button)
	review_archive_workspace.add_child(review_file_controls)
	new_game_dialog.confirmed.connect(confirm_new_game)
	new_game_dialog.get_ok_button().text = "시작"
	new_game_dialog.get_cancel_button().text = "취소"
	add_child(new_game_dialog)
	setup_dialog.title = ""
	setup_dialog.dialog_text = ""
	setup_dialog.confirmed.connect(apply_setup_selection)
	setup_dialog.get_ok_button().text = "적용"
	setup_dialog.get_cancel_button().text = "취소"
	var setup_form := VBoxContainer.new()
	setup_form.position = Vector2(20, 34)
	setup_form.custom_minimum_size = Vector2(440, 255)
	var setup_heading := Label.new()
	setup_heading.text = "기물 배치 선택"
	setup_heading.add_theme_font_size_override("font_size", 20)
	setup_form.add_child(setup_heading)
	var setup_hint := Label.new()
	setup_hint.text = "초와 한의 마·상 배치를 선택하세요."
	setup_form.add_child(setup_hint)
	var setup_cho_label := Label.new()
	setup_cho_label.text = "초 차림"
	setup_form.add_child(setup_cho_label)
	setup_form.add_child(cho_setup)
	var setup_han_label := Label.new()
	setup_han_label.text = "한 차림"
	setup_form.add_child(setup_han_label)
	setup_form.add_child(han_setup)
	setup_dialog.add_child(setup_form)
	add_child(setup_dialog)
	resign_dialog.dialog_text = "현재 차례 진영이 기권할까요?"
	resign_dialog.confirmed.connect(func(): act("resign", {"side": state.get("turn", "cho")}))
	add_child(resign_dialog)
	draw_dialog.dialog_text = "양쪽이 합의한 무승부로 대국을 종료할까요?"
	draw_dialog.confirmed.connect(func(): act("draw"))
	add_child(draw_dialog)
	api.timeout = 8.0
	api.request_completed.connect(on_response)
	add_child(api)
	timer.wait_time = 0.5
	timer.timeout.connect(request_state)
	add_child(timer)
	timer.start()
	render_board()
	if not load_offline_local():
		request_state()

func arrangement_value(index: int) -> String:
	return SETUPS[clampi(index, 0, 3)]

func arrangement_index(value: String) -> int:
	return maxi(SETUPS.find(value), 0)

func arrangement_label(value: String) -> String:
	return ["마상상마", "상마마상", "마상마상", "상마상마"][arrangement_index(value)]

func update_setup_summaries() -> void:
	var summary := "기물 배치 · 초 %s / 한 %s" % [arrangement_label(selected_cho_setup), arrangement_label(selected_han_setup)]
	ai_setup_summary.text = summary
	local_setup_summary.text = summary

func open_setup_dialog() -> void:
	cho_setup.select(arrangement_index(selected_cho_setup))
	han_setup.select(arrangement_index(selected_han_setup))
	setup_dialog.popup_centered(Vector2i(500, 410))

func apply_setup_selection() -> void:
	selected_cho_setup = arrangement_value(cho_setup.selected)
	selected_han_setup = arrangement_value(han_setup.selected)
	update_setup_summaries()

func sync_new_game_controls() -> void:
	if state.is_empty():
		return
	game_mode_tabs.current_tab = 1 if state.get("mode", "ai") == "local" else 0
	selected_cho_setup = str(state.get("setup", {}).get("cho", "nbbn"))
	selected_han_setup = str(state.get("setup", {}).get("han", "nbbn"))
	cho_setup.select(arrangement_index(selected_cho_setup))
	han_setup.select(arrangement_index(selected_han_setup))
	update_setup_summaries()
	cho_name.text = str(state.get("players", {}).get("cho", "초"))
	han_name.text = str(state.get("players", {}).get("han", "한"))
	var clock: Dictionary = state.get("clock", {})
	if not clock.get("enabled", false):
		time_control.select(0)
	elif int(clock.get("initialMs", 0)) == 300000:
		time_control.select(1)
	elif int(clock.get("initialMs", 0)) == 600000 and int(clock.get("incrementMs", 0)) == 5000:
		time_control.select(2)
	else:
		time_control.select(3)

func selected_time_control() -> Variant:
	match time_control.selected:
		1:
			return {"initialSeconds": 300, "incrementSeconds": 0}
		2:
			return {"initialSeconds": 600, "incrementSeconds": 5}
		3:
			return {"initialSeconds": 1800, "incrementSeconds": 0}
		_:
			return null

func local_initial_fen(setup: Dictionary) -> String:
	var han: String = str(setup.get("han", "nbbn"))
	var cho: String = str(setup.get("cho", "nbbn")).to_upper()
	return "r%sa1a%sr/4k4/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/4K4/R%sA1A%sR w - - 0 1" % [han.left(2), han.right(2), cho.left(2), cho.right(2)]

func material_points(fen: String) -> Dictionary:
	var values := {"r": 13.0, "c": 7.0, "n": 5.0, "b": 3.0, "a": 3.0, "p": 2.0, "k": 0.0}
	var points := {"cho": 0.0, "han": 1.5, "hanBonus": 1.5}
	for token in fen.split(" ")[0]:
		var lower := str(token).to_lower()
		if values.has(lower):
			points["cho" if str(token) == str(token).to_upper() else "han"] += float(values[lower])
	return points

func native_local_position(initial_fen: String, moves: Array[String]) -> Dictionary:
	if not ClassDB.class_exists("JanggiNative"):
		return {"error": "이 기기에는 로컬 장기 규칙이 없습니다."}
	if offline_native == null:
		offline_native = ClassDB.instantiate("JanggiNative")
	return offline_native.position(initial_fen, PackedStringArray(moves))

func refresh_offline_state(increment_revision := false) -> bool:
	var setup := {"cho": selected_cho_setup, "han": selected_han_setup}
	var initial_fen := local_initial_fen(setup)
	var position := native_local_position(initial_fen, offline_moves)
	if position.has("error"):
		message.text = "로컬 대국 복원 실패: %s" % str(position.error)
		return false
	var revision := int(state.get("revision", 0)) + (1 if increment_revision else 0)
	var outcome: Dictionary = offline_adjudication if not offline_adjudication.is_empty() else position.outcome
	state = {
		"fen": position.fen, "turn": position.turn, "inCheck": position.inCheck,
		"bikjang": position.get("bikjang", false), "legalMoves": Array(position.legalMoves),
		"points": material_points(str(position.fen)), "outcome": outcome,
		"initialFen": initial_fen, "setup": setup, "moves": offline_moves.duplicate(),
		"revision": revision, "variant": "janggi", "mode": "local", "humanSide": "cho",
		"players": {"cho": cho_name.text.strip_edges(), "han": han_name.text.strip_edges()},
		"clock": {
			"enabled": offline_time_control != null, "choMs": int(offline_clock.cho), "hanMs": int(offline_clock.han),
			"active": null if outcome.over or offline_time_control == null else position.turn,
			"initialMs": 0 if offline_time_control == null else int(offline_time_control.initialMs),
			"incrementMs": 0 if offline_time_control == null else int(offline_time_control.incrementMs),
		},
		"canUndo": not offline_moves.is_empty(), "ai": {"status": "idle", "error": null},
	}
	return true

func offline_review_position(moves: Array[String], allow_moves: bool, use_final_outcome := false) -> Dictionary:
	var position := native_local_position(str(state.initialFen), moves)
	if position.has("error"):
		message.text = "기기 복기 실패: %s" % str(position.error)
		return {}
	var snapshot := state.duplicate(true)
	snapshot["fen"] = position.fen
	snapshot["turn"] = position.turn
	snapshot["inCheck"] = position.inCheck
	snapshot["bikjang"] = position.get("bikjang", false)
	snapshot["legalMoves"] = Array(position.legalMoves) if allow_moves else []
	snapshot["points"] = material_points(str(position.fen))
	snapshot["outcome"] = state.outcome.duplicate(true) if use_final_outcome else position.outcome
	snapshot["moves"] = moves.duplicate()
	snapshot["canUndo"] = false
	snapshot["clock"] = state.get("clock", {}).duplicate(true)
	return snapshot

func save_offline_local() -> bool:
	if not offline_local or state.is_empty():
		return false
	var temporary_path := offline_save_path + ".tmp"
	if FileAccess.file_exists(temporary_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		message.text = "로컬 대국 저장 파일을 만들 수 없습니다."
		return false
	file.store_string(JSON.stringify({
		"version": 1, "setup": state.setup, "moves": offline_moves,
		"players": state.players, "timeControl": offline_time_control,
		"clock": offline_clock, "adjudication": offline_adjudication,
	}))
	file.flush()
	file.close()
	var absolute_save := ProjectSettings.globalize_path(offline_save_path)
	var absolute_backup := ProjectSettings.globalize_path(offline_backup_path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(offline_backup_path):
		DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(offline_save_path) and DirAccess.rename_absolute(absolute_save, absolute_backup) != OK:
		DirAccess.remove_absolute(absolute_temporary)
		message.text = "기존 로컬 대국을 보관하지 못해 저장을 중단했습니다."
		return false
	if DirAccess.rename_absolute(absolute_temporary, absolute_save) != OK:
		if FileAccess.file_exists(offline_backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_save)
		message.text = "로컬 대국 저장에 실패했습니다."
		return false
	print("OFFLINE_LOCAL_SAVED moves=%d" % offline_moves.size())
	return true

func load_offline_local() -> bool:
	if not ClassDB.class_exists("JanggiNative"):
		return false
	if load_offline_local_file(offline_save_path):
		return true
	if not load_offline_local_file(offline_backup_path):
		return false
	var absolute_save := ProjectSettings.globalize_path(offline_save_path)
	if FileAccess.file_exists(offline_save_path):
		DirAccess.remove_absolute(absolute_save)
	DirAccess.copy_absolute(ProjectSettings.globalize_path(offline_backup_path), absolute_save)
	message.text = "백업에서 로컬 대국을 복구했습니다."
	print("OFFLINE_LOCAL_BACKUP_RESTORED moves=%d" % offline_moves.size())
	return true

func load_offline_local_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var payload = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not payload is Dictionary or int(payload.get("version", 0)) != 1:
		return false
	var saved_setup = payload.get("setup", {})
	var saved_players = payload.get("players", {})
	var saved_clock = payload.get("clock", {})
	var saved_moves = payload.get("moves", [])
	var saved_adjudication = payload.get("adjudication", {})
	if not saved_setup is Dictionary or not saved_players is Dictionary or not saved_clock is Dictionary or not saved_moves is Array or not saved_adjudication is Dictionary:
		return false
	selected_cho_setup = str(saved_setup.get("cho", "nbbn"))
	selected_han_setup = str(saved_setup.get("han", "nbbn"))
	if selected_cho_setup not in SETUPS or selected_han_setup not in SETUPS:
		return false
	offline_moves.assign(payload.get("moves", []))
	offline_adjudication = saved_adjudication.duplicate(true)
	offline_time_control = payload.get("timeControl")
	if offline_time_control != null and (not offline_time_control is Dictionary or not offline_time_control.has("initialMs") or not offline_time_control.has("incrementMs")):
		return false
	if not saved_clock.has("cho") or not saved_clock.has("han"):
		return false
	offline_clock = saved_clock.duplicate(true)
	cho_name.text = str(saved_players.get("cho", "초"))
	han_name.text = str(saved_players.get("han", "한"))
	offline_local = true
	offline_clock_started = Time.get_ticks_msec()
	if not refresh_offline_state(true):
		offline_local = false
		return false
	sync_new_game_controls()
	message.text = "기기에 저장된 로컬 대국을 복원했습니다."
	print("OFFLINE_LOCAL_RESTORED moves=%d" % offline_moves.size())
	render_board()
	return true

func start_offline_local() -> void:
	offline_local = true
	offline_moves = []
	offline_adjudication = {}
	var selected_control = selected_time_control()
	offline_time_control = null if selected_control == null else {
		"initialMs": int(selected_control.initialSeconds) * 1000,
		"incrementMs": int(selected_control.incrementSeconds) * 1000,
	}
	var initial_ms := 0 if offline_time_control == null else int(offline_time_control.initialMs)
	offline_clock = {"cho": initial_ms, "han": initial_ms}
	offline_clock_started = Time.get_ticks_msec()
	state = {"revision": int(state.get("revision", 0))}
	if refresh_offline_state(true):
		if save_offline_local():
			message.text = "오프라인 로컬 대국을 시작했습니다."
			print("OFFLINE_LOCAL_STARTED")
		else:
			message.text = "로컬 대국을 시작했지만 기기에 저장할 수 없습니다."
		render_board()

func sync_offline_clock() -> void:
	if not offline_local or offline_time_control == null or state.is_empty() or state.outcome.over:
		return
	var previous_clock := offline_clock.duplicate(true)
	var now := Time.get_ticks_msec()
	var side_key: String = str(state.turn)
	offline_clock[side_key] = maxi(0, int(offline_clock[side_key]) - maxi(0, now - offline_clock_started))
	offline_clock_started = now
	if int(offline_clock[side_key]) == 0:
		var winner := "han" if side_key == "cho" else "cho"
		offline_adjudication = {"over": true, "result": "0-1" if winner == "han" else "1-0", "winner": winner, "reason": "시간패"}
		refresh_offline_state(true)
		if not save_offline_local():
			offline_clock = previous_clock
			offline_adjudication = {}
			refresh_offline_state(false)

func open_new_game_dialog(mode: String) -> void:
	pending_new_mode = mode
	game_mode_tabs.current_tab = 1 if mode == "local" else 0
	new_game_dialog.dialog_text = "현재 대국을 지우고 새 %s 대국을 시작할까요?" % ("로컬" if mode == "local" else "AI")
	new_game_dialog.popup_centered()

func confirm_new_game() -> void:
	if pending_new_mode == "local" and ClassDB.class_exists("JanggiNative"):
		start_offline_local()
		return
	if pending_new_mode == "ai" and offline_local:
		offline_local = false
		offline_native = null
		for path in [offline_save_path, offline_backup_path, offline_save_path + ".tmp"]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		pending_ai_start_after_connect = true
		state = {}
		request_state()
		return
	act("reset", {
		"mode": pending_new_mode,
		"humanSide": "cho" if side.selected == 0 else "han",
		"setup": {"cho": selected_cho_setup, "han": selected_han_setup},
		"players": {"cho": cho_name.text.strip_edges(), "han": han_name.text.strip_edges()},
		"timeControl": selected_time_control() if pending_new_mode == "local" else null,
	})

func _exit_tree() -> void:
	device_engine.shutdown()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		cancel_device_recommendation()
		sync_offline_clock()
		save_offline_local()
	elif what == NOTIFICATION_APPLICATION_RESUMED and offline_local:
		offline_clock_started = Time.get_ticks_msec()

func add_action(parent: Node, caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	parent.add_child(button)
	action_buttons.append(button)

func request_state() -> void:
	if offline_local:
		sync_offline_clock()
		refresh_offline_state(false)
		render_board()
		return
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
	if current_path in ["review-start", "review-status", "review-latest", "review-cancel"]:
		if current_path == "review-latest" and payload.get("status", "") == "none":
			import_full_review(false)
			render_board()
			return
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
				export_full_review(false)
				if open_review_when_ready:
					open_review_when_ready = false
					call_deferred("open_guided_review")
			elif payload.status == "cancelled":
				open_review_when_ready = false
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
		sync_new_game_controls()
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
	if pending_ai_start_after_connect:
		pending_ai_start_after_connect = false
		act("reset", {
			"mode": "ai", "humanSide": "cho" if side.selected == 0 else "han",
			"setup": {"cho": selected_cho_setup, "han": selected_han_setup},
			"players": {"cho": cho_name.text.strip_edges(), "han": han_name.text.strip_edges()},
			"timeControl": null,
		})
		return
	if review_restore_revision != int(state.revision):
		review_restore_revision = int(state.revision)
		send("review-latest", {"revision": state.revision})

func act(action: String, data: Dictionary = {}) -> void:
	if state.is_empty() or pending or not review.is_empty():
		return
	if offline_local:
		act_offline_local(action, data)
		return
	cancel_device_recommendation(false)
	data["revision"] = state.revision
	send(action, data)

func act_offline_local(action: String, data: Dictionary = {}) -> void:
	sync_offline_clock()
	if state.outcome.over and action == "move":
		message.text = "종료된 대국입니다."
		return
	var previous_moves := offline_moves.duplicate()
	var previous_adjudication := offline_adjudication.duplicate(true)
	var previous_clock := offline_clock.duplicate(true)
	if action == "move":
		var move := str(data.get("move", ""))
		if not state.legalMoves.has(move):
			message.text = "둘 수 없는 수입니다."
			return
		var mover: String = str(state.turn)
		offline_moves.append(move)
		if offline_time_control != null:
			offline_clock[mover] = int(offline_clock[mover]) + int(offline_time_control.incrementMs)
		offline_adjudication = {}
	elif action == "undo":
		if offline_moves.is_empty():
			return
		offline_moves.pop_back()
		offline_adjudication = {}
	elif action == "resign":
		var loser: String = str(data.get("side", state.turn))
		var winner := "han" if loser == "cho" else "cho"
		offline_adjudication = {"over": true, "result": "0-1" if winner == "han" else "1-0", "winner": winner, "reason": "기권"}
	elif action == "draw":
		offline_adjudication = {"over": true, "result": "1/2-1/2", "winner": null, "reason": "합의 무승부"}
	else:
		message.text = "오프라인 로컬 대국에서 지원하지 않는 동작입니다."
		return
	offline_clock_started = Time.get_ticks_msec()
	if refresh_offline_state(true):
		selected = ""
		if not save_offline_local():
			offline_moves.assign(previous_moves)
			offline_adjudication = previous_adjudication
			offline_clock = previous_clock
			refresh_offline_state(false)
			message.text = "저장하지 못해 방금 동작을 되돌렸습니다."
		render_board()

func start_full_review() -> void:
	if pending or state.is_empty() or state.moves.is_empty() or full_review.get("status", "") == "running":
		return
	if offline_local:
		show_review(1)
		message.text = "기기에 저장된 기보를 복기합니다. 정밀 등급 리뷰는 서버 연결 후 사용할 수 있습니다."
		return
	open_review_when_ready = true
	return_live()
	send("review-start", {"revision": state.revision})

func open_guided_review() -> void:
	if pending or state.is_empty() or state.moves.is_empty():
		return
	var first_key := next_key_ply(0)
	show_review(first_key if first_key > 0 else 1)

func cancel_full_review() -> void:
	if pending or full_review.get("status", "") != "running":
		return
	send("review-cancel", {"revision": state.revision, "jobId": full_review.jobId})

func export_full_review(notify_user := true) -> bool:
	if full_review.get("status", "") != "complete" or state.is_empty():
		return false
	var payload := {
		"schemaVersion": 1,
		"variant": "janggi",
		"game": {
			"revision": state.revision,
			"initialFen": state.initialFen,
			"setup": state.setup,
			"moves": state.moves,
			"mode": state.get("mode", "practice"),
			"players": state.get("players", {"cho": "초", "han": "한"}),
			"outcome": state.get("outcome", {}),
			"clock": state.get("clock", {}),
		},
		"review": full_review,
	}
	var file := FileAccess.open(review_export_path, FileAccess.WRITE)
	if file == null:
		if notify_user:
			message.text = "리뷰 JSON 저장에 실패했습니다."
		return false
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	if notify_user:
		message.text = "리뷰 JSON 저장 완료 · %s" % review_export_path
		render_board()
	return true

func valid_imported_review(payload: Variant) -> bool:
	if not payload is Dictionary or int(payload.get("schemaVersion", 0)) != 1 or payload.get("variant", "") != "janggi":
		return false
	var game: Variant = payload.get("game")
	var imported_review: Variant = payload.get("review")
	if not game is Dictionary or not imported_review is Dictionary:
		return false
	if int(game.get("revision", -1)) != int(state.get("revision", -2)) or game.get("initialFen", "") != state.get("initialFen", ""):
		return false
	if game.get("moves", []) != state.get("moves", []) or imported_review.get("status", "") != "complete":
		return false
	if int(imported_review.get("revision", -1)) != int(state.revision) or not imported_review.get("results") is Array or not imported_review.get("summary") is Dictionary:
		return false
	var results: Array = imported_review.results
	if results.size() != state.moves.size() or int(imported_review.get("total", -1)) != state.moves.size():
		return false
	if int(imported_review.summary.get("total", -1)) != results.size():
		return false
	for index in range(results.size()):
		if not valid_imported_review_entry(results[index], index):
			return false
	return true

func valid_imported_review_entry(value: Variant, index: int) -> bool:
	if not value is Dictionary:
		return false
	var item: Dictionary = value
	if int(item.get("revision", -1)) != int(state.revision) or int(item.get("ply", -1)) != index + 1:
		return false
	if item.get("side", "") != ("cho" if index % 2 == 0 else "han") or item.get("playedMove", "") != state.moves[index]:
		return false
	if split_move(str(item.get("recommendedMove", ""))).size() != 2 or not item.get("classification") is Dictionary or not item.get("analysis") is Dictionary:
		return false
	var classification: Dictionary = item.classification
	if not classification.get("key", "") in ["best", "excellent", "good", "inaccuracy", "mistake", "blunder", "unclassified"] or str(classification.get("label", "")) == "":
		return false
	if not item.get("prediction") is Dictionary or str(item.get("beforeFen", "")) == "" or str(item.get("recommendedFen", "")) == "":
		return false
	var prediction: Dictionary = item.prediction
	if not prediction.get("moves") is Array or not prediction.get("fens") is Array:
		return false
	return prediction.fens.size() == prediction.moves.size() + 1

func import_full_review(notify_user := true) -> bool:
	if state.is_empty() or not FileAccess.file_exists(review_export_path):
		return false
	var payload = JSON.parse_string(FileAccess.get_file_as_string(review_export_path))
	if not valid_imported_review(payload):
		if notify_user:
			message.text = "현재 대국과 일치하는 리뷰 JSON이 아닙니다."
			render_board()
		return false
	full_review = payload.review.duplicate(true)
	evaluation_graph.set_results(full_review.results)
	review_summary.text = format_review_summary(full_review.summary)
	message.text = ("리뷰 JSON 불러오기 완료" if notify_user else "저장된 리뷰 자동 복원") + " · %d수" % int(full_review.total)
	render_board()
	return true

func view_ply() -> int:
	return review.moves.size() if not review.is_empty() else state.get("moves", []).size()

func show_review(ply: int, keep_game_playback := false) -> void:
	if pending or state.is_empty() or not variation.is_empty() or ply < 0 or ply > state.moves.size():
		return
	if not keep_game_playback:
		game_review_generation += 1
		game_review_playing = false
	cancel_device_recommendation(false)
	clear_review_analysis()
	selected = ""
	if offline_local:
		var review_moves: Array[String] = []
		review_moves.assign(offline_moves.slice(0, ply))
		review = offline_review_position(review_moves, false, ply == offline_moves.size())
		if not review.is_empty():
			message.text = "기기 복기 · %d/%d수" % [ply, offline_moves.size()]
			render_board()
		return
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
	if offline_local:
		refresh_offline_variation()
		return
	send("variation", {"revision": state.revision, "basePly": variation_start_ply, "moves": variation_moves})

func refresh_offline_variation() -> void:
	var combined: Array[String] = []
	combined.assign(offline_moves.slice(0, variation_start_ply))
	combined.append_array(variation_moves)
	variation = offline_review_position(combined, true)
	if variation.is_empty():
		return
	variation["variation"] = {"basePly": variation_start_ply, "moves": variation_moves.duplicate()}
	variation["canUndo"] = not variation_moves.is_empty()
	selected = ""
	message.text = "기기 자유 분석 · 초와 한을 번갈아 둘 수 있습니다."
	schedule_variation_evaluation()
	render_board()

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

func retry_succeeded() -> bool:
	return retry_mode and variation_moves.size() == 1 and variation_moves[0] == retry_expected_move

func continue_retry_to_next_key() -> void:
	if pending or not retry_succeeded():
		return
	var target_ply := next_key_ply(retry_review_ply)
	if target_ply < 0:
		return
	clear_variation()
	retry_mode = false
	retry_review_ply = -1
	retry_expected_move = ""
	retry_hint_stage = 0
	selected = ""
	show_review(target_ply)

func play_variation_move(move: String) -> void:
	if pending or variation.is_empty() or not variation.legalMoves.has(move):
		return
	var next_moves := variation_moves.duplicate()
	next_moves.append(move)
	if offline_local:
		variation_moves.assign(next_moves)
		refresh_offline_variation()
		return
	send("variation", {"revision": state.revision, "basePly": variation_start_ply, "moves": next_moves})

func undo_variation() -> void:
	if pending or variation.is_empty() or variation_moves.is_empty():
		return
	var next_moves := variation_moves.duplicate()
	next_moves.pop_back()
	if offline_local:
		variation_moves.assign(next_moves)
		refresh_offline_variation()
		return
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
	if summary.get("bestMoveRate") != null:
		text += " · 최선수 일치 %d%%" % int(summary.bestMoveRate)
	if summary.get("averageDepth") != null:
		text += " · 평균 깊이 %d" % int(summary.averageDepth)
	if int(summary.get("totalAnalysisMs", 0)) > 0:
		text += " · 엔진 %.1f초" % (float(summary.totalAnalysisMs) / 1000.0)
	var worst: Variant = summary.get("worstMove")
	if worst is Dictionary:
		text += "\n최대 손실 · %d수 %s · %dcp" % [int(worst.get("ply", 0)), "초" if worst.get("side") == "cho" else "한", int(worst.get("lossCp", 0))]
	if summary.get("averageLossCp") != null:
		text += " · 비교 가능 %d수 · 평균 손실 %dcp" % [int(summary.get("comparableMoves", 0)), int(summary.averageLossCp)]
	var by_side: Dictionary = summary.get("bySide", {})
	for side_key in ["cho", "han"]:
		var side_summary: Dictionary = by_side.get(side_key, {})
		if side_summary.get("averageLossCp") != null:
			text += "\n%s %d수 · 핵심 %d수 · 평균 손실 %dcp" % ["초" if side_key == "cho" else "한", int(side_summary.get("total", 0)), int(side_summary.get("keyMoves", 0)), int(side_summary.averageLossCp)]
	return text

func format_review_method_notice() -> String:
	if full_review.get("status", "") != "complete" or full_review.get("results", []).is_empty():
		return ""
	var budget := int(full_review.results[0].get("budgetMs", 0))
	return "실험적 수 등급 · 서버 엔진 %dms 기준 · 장기 기보 보정 전" % budget

func next_key_ply(after_ply: int) -> int:
	if full_review.get("status", "") != "complete":
		return -1
	for item in full_review.get("results", []):
		var key := str(item.get("classification", {}).get("key", ""))
		if int(item.get("ply", -1)) > after_ply and is_key_classification(key):
			return int(item.ply)
	return -1

func previous_key_ply(before_ply: int) -> int:
	var results: Array = full_review.get("results", [])
	for index in range(results.size() - 1, -1, -1):
		var item: Dictionary = results[index]
		var key := str(item.get("classification", {}).get("key", ""))
		if int(item.get("ply", -1)) < before_ply and is_key_classification(key):
			return int(item.ply)
	return -1

func previous_key_move() -> void:
	if pending or review.is_empty() or not variation.is_empty():
		return
	var ply := previous_key_ply(view_ply())
	if ply >= 0:
		show_review(ply)

func is_key_classification(key: String) -> bool:
	match key_move_filter.selected:
		1:
			return key in ["mistake", "blunder"]
		2:
			return key == "blunder"
		_:
			return key in ["inaccuracy", "mistake", "blunder"]

func format_key_move_status(ply: int) -> String:
	var key_plies: Array[int] = []
	for item in full_review.get("results", []):
		var key := str(item.get("classification", {}).get("key", ""))
		if is_key_classification(key):
			key_plies.append(int(item.get("ply", -1)))
	if key_plies.is_empty():
		return ""
	var current_index := key_plies.find(ply)
	if current_index >= 0:
		return "핵심 장면 %d/%d" % [current_index + 1, key_plies.size()]
	return "핵심 장면 %d개" % key_plies.size()

func format_current_review_status(ply: int) -> String:
	var item := cached_review_result(ply)
	if item.is_empty():
		return ""
	var label := str(item.get("classification", {}).get("label", "분류 제외"))
	var loss: Variant = item.get("analysis", {}).get("lossCp")
	return "현재 수 · %s%s" % [label, " · %dcp 손실" % int(loss) if loss != null else " · 손실 비교 제외"]

func next_key_move() -> void:
	if pending or review.is_empty() or not variation.is_empty():
		return
	var ply := next_key_ply(view_ply())
	if ply >= 0:
		show_review(ply)

func worst_move_ply() -> int:
	var worst: Variant = full_review.get("summary", {}).get("worstMove")
	return int(worst.get("ply", -1)) if worst is Dictionary else -1

func show_worst_move() -> void:
	if pending or not variation.is_empty():
		return
	var ply := worst_move_ply()
	if ply > 0:
		show_review(ply)

func clear_review_analysis() -> void:
	analysis_generation += 1
	prediction_generation += 1
	prediction_playing = false
	prediction_index = -1
	review_analysis = {}
	analysis_preview = {}
	analysis_move = ""
	analysis_stage = 0
	playback_move = ""

func play_prediction() -> void:
	if pending or review.is_empty() or not variation.is_empty() or review_analysis.is_empty():
		return
	var fens: Array = review_analysis.get("prediction", {}).get("fens", [])
	if fens.size() < 2:
		return
	prediction_generation += 1
	var generation := prediction_generation
	prediction_playing = true
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
		playback_move = str(review_analysis.prediction.moves[index - 1]) if index > 0 else ""
		message.text = "엔진 예상 수순 재생 · %d/%d" % [index, fens.size() - 1]
		render_board()
		if index > 0:
			animate_piece_move(str(review_analysis.prediction.moves[index - 1]))
		if index < fens.size() - 1:
			await get_tree().create_timer(playback_delay()).timeout
	if generation == prediction_generation:
		prediction_playing = false
		render_board()

func stop_prediction() -> void:
	if not prediction_playing:
		return
	prediction_generation += 1
	prediction_playing = false
	var total: int = review_analysis.get("prediction", {}).get("fens", []).size() - 1
	message.text = "엔진 예상 수순 정지 · %d/%d" % [maxi(prediction_index, 0), maxi(total, 0)]
	render_board()

func step_prediction(offset: int) -> void:
	if review.is_empty() or not variation.is_empty() or review_analysis.is_empty():
		return
	var fens: Array = review_analysis.get("prediction", {}).get("fens", [])
	if fens.size() < 2:
		return
	if prediction_playing:
		prediction_generation += 1
		prediction_playing = false
	var current := prediction_index if prediction_index >= 0 else 0
	var next_index: int = clampi(current + offset, 0, fens.size() - 1)
	var preview := review.duplicate(true)
	preview["fen"] = fens[next_index]
	preview["legalMoves"] = []
	preview["outcome"] = {"over": false, "result": "*", "winner": null, "reason": null}
	analysis_preview = preview
	prediction_index = next_index
	playback_move = str(review_analysis.prediction.moves[next_index - 1]) if next_index > 0 else ""
	analysis_generation += 1
	analysis_move = ""
	analysis_stage = 0
	message.text = "엔진 예상 수순 · %d/%d" % [next_index, fens.size() - 1]
	render_board()
	if next_index != current:
		var move: String = str(review_analysis.prediction.moves[mini(current, next_index)])
		animate_piece_move(move if next_index > current else reverse_move(move))

func play_game_review() -> void:
	if pending or state.is_empty() or state.moves.is_empty() or not variation.is_empty():
		return
	game_review_generation += 1
	var generation := game_review_generation
	game_review_playing = true
	for ply in range(state.moves.size() + 1):
		if generation != game_review_generation or not variation.is_empty():
			return
		show_review(ply, true)
		while pending:
			await get_tree().process_frame
		if generation != game_review_generation:
			return
		message.text = "기보 재생 · %d/%d수" % [ply, state.moves.size()]
		playback_move = str(state.moves[ply - 1]) if ply > 0 else ""
		render_board()
		if ply > 0:
			animate_piece_move(str(state.moves[ply - 1]))
		if ply < state.moves.size():
			await get_tree().create_timer(playback_delay()).timeout
	if generation == game_review_generation:
		game_review_playing = false
		render_board()

func stop_game_review() -> void:
	if not game_review_playing:
		return
	game_review_generation += 1
	game_review_playing = false
	message.text = "기보 재생 정지 · %d/%d수" % [view_ply(), state.moves.size()]
	render_board()

func playback_delay() -> float:
	match playback_speed.selected:
		0:
			return 1.0
		2:
			return 0.25
		_:
			return 0.55

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
	animate_piece_move(analysis_move)

func reverse_move(move: String) -> String:
	var coordinates := split_move(move)
	return str(coordinates[1]) + str(coordinates[0]) if coordinates.size() == 2 else ""

func animate_piece_move(move: String) -> void:
	var coordinates := split_move(move)
	if coordinates.size() != 2:
		return
	last_animated_move = move
	call_deferred("run_piece_move_animation", str(coordinates[0]), str(coordinates[1]))

func run_piece_move_animation(from_square: String, to_square: String) -> void:
	await get_tree().process_frame
	if not squares.has(from_square) or not squares.has(to_square):
		return
	var source: Control = squares[from_square]
	var destination: Control = squares[to_square]
	var target_position := destination.position
	destination.position += source.position - target_position
	destination.z_index = 2
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(destination, "position", target_position, piece_move_animation_seconds)

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
	var before: Dictionary = analysis.get("before", {}) if analysis.get("before") is Dictionary else {}
	var classification: Dictionary = payload.get("classification", {})
	var result := "%d수 · 실험 등급 %s · 서버 추천 · 전 %s / 실제 수 후 %s" % [
		int(payload.ply), str(classification.get("label", "분류 제외")),
		format_evaluation(analysis.get("before")), format_evaluation(analysis.get("after")),
	]
	if not before.is_empty():
		result += " · 깊이 %d · %d노드 · %dms" % [int(before.get("depth", 0)), int(before.get("nodes", 0)), int(before.get("timeMs", 0))]
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

func local_match_active() -> bool:
	return not state.is_empty() and state.get("mode", "") == "local" and not state.get("outcome", {}).get("over", false)

func format_clock(milliseconds: int) -> String:
	var total_seconds := maxi(milliseconds, 0) / 1000
	return "%02d:%02d" % [int(total_seconds / 60), int(total_seconds) % 60]

func render_position(state: Dictionary) -> void:
	history.disabled = local_match_active() or pending or self.state.is_empty()
	for button in review_buttons:
		button.disabled = pending or self.state.is_empty()
	review_analysis_button.disabled = pending or review.is_empty() or view_ply() < 1
	if state.is_empty():
		score_panel.text = ""
		clock_panel.text = ""
		for button in action_buttons:
			button.disabled = true
		device_recommend.disabled = true
		device_cancel.disabled = true
		resign_button.disabled = true
		draw_button.disabled = true
		rematch_button.disabled = true
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
			var square_color := Color("fff9ed") if (row + file) % 2 == 0 else Color("f7e6cf")
			button.add_theme_stylebox_override("normal", board_box(square_color))
			button.add_theme_stylebox_override("disabled", board_box(square_color.darkened(0.03)))
			button.add_theme_color_override("font_color", Color("5687a0") if piece != "" and piece == piece.to_upper() else Color("c8796d") if piece != "" else Color("ccb8a6"))
			button.add_theme_color_override("font_disabled_color", Color("6f9aaf") if piece != "" and piece == piece.to_upper() else Color("ce8b81") if piece != "" else Color("cfbdad"))
			if square == selected or (selected != "" and state.legalMoves.has(selected + square)):
				button.modulate = Color("c8efa9")
			var recommendation := split_move(recommended_move)
			if recommendation.size() == 2 and square == recommendation[0]:
				button.modulate = Color("ffd97b")
			elif recommendation.size() == 2 and square == recommendation[1]:
				button.modulate = Color("9ee3b5")
			var review_recommendation := split_move(analysis_move)
			if review_recommendation.size() == 2 and square == review_recommendation[0]:
				button.modulate = Color("ffd27a")
			elif review_recommendation.size() == 2 and analysis_stage == 2 and square == review_recommendation[1]:
				button.modulate = Color("94ddb0")
			var playback_highlight := split_move(playback_move)
			if analysis_move == "" and playback_highlight.size() == 2 and square == playback_highlight[0]:
				button.modulate = Color("ffd27a")
			elif analysis_move == "" and playback_highlight.size() == 2 and square == playback_highlight[1]:
				button.modulate = Color("94ddb0")
			var retry_hint := split_move(retry_expected_move)
			if retry_mode and retry_hint.size() == 2 and retry_hint_stage >= 1 and square == retry_hint[0]:
				button.modulate = Color("ffd27a")
			elif retry_mode and retry_hint.size() == 2 and retry_hint_stage >= 2 and square == retry_hint[1]:
				button.modulate = Color("94ddb0")
			button.disabled = (not review.is_empty() and variation.is_empty()) or (pending and current_path != "game") or ai_turn or state.outcome.over
			button.pressed.connect(choose.bind(square, piece))
			grid.add_child(button)
			squares[square] = button
	var players: Dictionary = state.get("players", {"cho": "초", "han": "한"})
	status.text = "%s(%s) 차례 · %d수" % [str(players.get(state.turn, state.turn)), "초" if state.turn == "cho" else "한", state.moves.size()]
	status.text += " · 로컬 대국" if state.get("mode", "") == "local" else " · AI %s" % str(state.ai.status)
	if state.inCheck:
		status.text += " · 장군"
	if state.outcome.over:
		var result_text := "무승부" if state.outcome.get("winner") == null else "%s(%s) 승리" % [str(players.get(state.outcome.winner, state.outcome.winner)), "초" if state.outcome.winner == "cho" else "한"]
		status.text = "대국 종료 · %s · %s" % [result_text, state.outcome.reason]
	if state.ai.status == "error":
		status.text += " · " + str(state.ai.error)
	var clock: Dictionary = state.get("clock", {})
	clock_panel.text = ""
	if clock.get("enabled", false):
		clock_panel.text = "대국 시계 · 초 %s / 한 %s%s" % [
			format_clock(int(clock.get("choMs", 0))), format_clock(int(clock.get("hanMs", 0))),
			" · 매 수 +%d초" % (int(clock.get("incrementMs", 0)) / 1000) if int(clock.get("incrementMs", 0)) > 0 else "",
		]
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
	device_recommend.disabled = local_match_active() or not variation.is_empty() or not device_engine.available() or device_engine.busy() or state.outcome.over or state.legalMoves.is_empty()
	device_cancel.disabled = not variation.is_empty() or not device_engine.busy()
	full_review_start.text = "기보 복기 시작" if offline_local else ("리뷰 다시 보기" if full_review.get("status", "") == "complete" else "게임 리뷰 시작")
	full_review_start.disabled = local_match_active() or pending or self.state.moves.is_empty() or full_review.get("status", "") == "running"
	full_review_cancel.disabled = pending or full_review.get("status", "") != "running"
	review_export_button.disabled = pending or full_review.get("status", "") != "complete"
	review_import_button.disabled = pending or state.is_empty() or not FileAccess.file_exists(review_export_path)
	if not review.is_empty():
		status.text = "복기 %d/%d수 · %s" % [view_ply(), self.state.moves.size(), status.text]
	if not analysis_preview.is_empty():
		status.text = "서버 추천 수 재생 · " + status.text
	history.clear()
	history.add_item("0수 · 시작 배치")
	for index in range(self.state.moves.size()):
		var pair := split_move(self.state.moves[index])
		var description: String = "한수쉼" if pair[0] == pair[1] else "%s → %s" % [pair[0], pair[1]]
		var classification_suffix := ""
		var reviewed := cached_review_result(index + 1)
		if not reviewed.is_empty():
			var classification: Dictionary = reviewed.get("classification", {})
			classification_suffix = " · [%s]" % str(classification.get("label", "분류 제외"))
			if reviewed.get("analysis", {}).get("lossCp") != null:
				classification_suffix += " %dcp" % int(reviewed.analysis.lossCp)
		history.add_item("%d수 · %s %s%s" % [index + 1, "초" if index % 2 == 0 else "한", description, classification_suffix])
	history.select(view_ply())
	evaluation_graph.select_ply(view_ply())
	var review_status_parts: Array[String] = []
	for detail in [format_key_move_status(view_ply()), format_current_review_status(view_ply())]:
		if detail != "":
			review_status_parts.append(detail)
	key_move_status.text = " · ".join(review_status_parts)
	review_method_notice.text = format_review_method_notice()
	review_buttons[0].disabled = pending or self.state.moves.is_empty()
	review_buttons[1].disabled = pending or view_ply() == 0
	review_buttons[2].disabled = pending or review.is_empty() or view_ply() >= self.state.moves.size()
	review_buttons[3].disabled = pending or review.is_empty()
	review_analysis_button.disabled = offline_local or pending or review.is_empty() or view_ply() < 1
	for button in review_buttons:
		button.disabled = button.disabled or not variation.is_empty()
	review_analysis_button.disabled = review_analysis_button.disabled or not variation.is_empty()
	variation_start.disabled = pending or review.is_empty() or not variation.is_empty()
	variation_undo.disabled = pending or variation.is_empty() or variation_moves.is_empty()
	variation_resume.disabled = pending or variation.is_empty()
	previous_key_move_button.disabled = pending or review.is_empty() or not variation.is_empty() or previous_key_ply(view_ply()) < 0
	next_key_move_button.disabled = pending or review.is_empty() or not variation.is_empty() or next_key_ply(view_ply()) < 0
	worst_move_button.disabled = pending or not variation.is_empty() or worst_move_ply() < 1
	retry_button.disabled = pending or review.is_empty() or not variation.is_empty() or view_ply() < 1 or cached_review_result(view_ply()).is_empty()
	retry_hint_button.disabled = pending or not retry_mode or variation.is_empty() or not variation_moves.is_empty() or retry_hint_stage >= 2
	retry_next_button.disabled = pending or not retry_succeeded() or next_key_ply(retry_review_ply) < 0
	prediction_button.disabled = pending or review.is_empty() or not variation.is_empty() or review_analysis.get("prediction", {}).get("fens", []).size() < 2
	prediction_stop_button.disabled = not prediction_playing
	var prediction_size: int = review_analysis.get("prediction", {}).get("fens", []).size()
	prediction_previous_button.disabled = pending or review.is_empty() or not variation.is_empty() or prediction_size < 2 or prediction_index <= 0
	prediction_next_button.disabled = pending or review.is_empty() or not variation.is_empty() or prediction_size < 2 or prediction_index >= prediction_size - 1
	game_review_play_button.disabled = pending or state.moves.is_empty() or not variation.is_empty() or game_review_playing
	game_review_stop_button.disabled = not game_review_playing
	if local_match_active():
		for button in review_buttons:
			button.disabled = true
		review_analysis_button.disabled = true
		variation_start.disabled = true
	resign_button.disabled = pending or not local_match_active()
	draw_button.disabled = pending or not local_match_active()
	rematch_button.disabled = pending or state.get("mode", "") != "local" or not state.outcome.over
