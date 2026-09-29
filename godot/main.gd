extends Control

const LocalEngine = preload("res://local_engine.gd")
const EvaluationGraph = preload("res://evaluation_graph.gd")
const SETUPS := ["nbbn", "bnbn", "nbnb", "bnnb"]

var state: Dictionary = {}
var selected := ""
var pending := false
var api := HTTPRequest.new()
var endpoint := LineEdit.new()
var server_controls := VBoxContainer.new()
var server_toggle := Button.new()
var account_badge := Label.new()
var current_role := "user"
var screen_mode := "home"
var home_section := "dashboard"
var home_button := Button.new()
var play_button := Button.new()
var status := Label.new()
var message := Label.new()
var score_panel := Label.new()
var match_setup_panel := Label.new()
var last_move_panel := Label.new()
var review_summary := Label.new()
var review_method_notice := Label.new()
var key_move_status := Label.new()
var grid := preload("res://janggi_board.gd").new()
var side := OptionButton.new()
var ai_difficulty := OptionButton.new()
var cho_setup := OptionButton.new()
var han_setup := OptionButton.new()
var time_control := OptionButton.new()
var cho_name := LineEdit.new()
var han_name := LineEdit.new()
var clock_panel := Label.new()
var game_mode_tabs := TabContainer.new()
var game_setup_toggle := Button.new()
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
var game_actions := HFlowContainer.new()
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
var app_background := ColorRect.new()
var app_title := Label.new()
var home_dashboard := VBoxContainer.new()
var home_stats := Label.new()
var home_recent_text := ""
var board_credit := RichTextLabel.new()
var bottom_navigation := HBoxContainer.new()
var coming_soon := AcceptDialog.new()
var recent_game_button := Button.new()
var primary_play := Button.new()
var board_row := HBoxContainer.new()
var advantage_bar = preload("res://advantage_bar.gd").new()
var compact_review_header := VBoxContainer.new()
var compact_grade := Label.new()
var compact_advantage := Label.new()
var compact_review_footer := VBoxContainer.new()
var compact_move := Label.new()
var compact_previous := Button.new()
var compact_next := Button.new()
var compact_resume := Button.new()
var review_overlay = preload("res://review_overlay.gd").new()
var branch_api := HTTPRequest.new()
var branch_entry: Dictionary = {}
var branch_error := ""
var branch_busy := false
var branch_fen := ""
var branch_moves: Array = []
var branch_first_square := ""
var branch_first_piece := ""
var compact_analyze := Button.new()
var record_open_requested := false
var review_grade_requested := false
var record_panel := VBoxContainer.new()
var record_result := Label.new()
var record_details := Label.new()
var record_counts: Dictionary = {}
var record_status := Label.new()
var record_progress := ProgressBar.new()
var record_start := Button.new()
var record_browse := Button.new()
var record_error := ""
var record_identity := ""
var record_enter_when_ready := false
var light_theme: Theme

func add_section_title(parent: Control, caption: String) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("7a5448"))
	parent.add_child(label)

func style_dashboard_button(button: Button, primary := false) -> void:
	button.custom_minimum_size.y = 76 if not primary else 64
	button.add_theme_font_size_override("font_size", 18 if not primary else 22)
	button.add_theme_color_override("font_color", Color("684a40"))
	button.add_theme_color_override("font_hover_color", Color("684a40"))
	button.add_theme_stylebox_override("normal", cream_box(Color("f6d3aa") if primary else Color("fffaf2")))
	button.add_theme_stylebox_override("hover", cream_box(Color("f2c48f") if primary else Color("fff0da")))
	button.add_theme_stylebox_override("pressed", cream_box(Color("eab880") if primary else Color("f4dfc5")))

func show_home_setup(tab := 0) -> void:
	screen_mode = "home"
	home_section = "setup"
	game_mode_tabs.current_tab = tab
	sync_screen_visibility()
	call_deferred("reveal_home_control", game_mode_tabs)

func show_home_review(tab := 0) -> void:
	open_game_record()

func show_coming_soon() -> void:
	coming_soon.dialog_text = "준비중"
	coming_soon.popup_centered(Vector2i(280, 130))

func open_game_record() -> void:
	if state.is_empty():
		return
	screen_mode = "home"
	home_section = "record"
	record_error = ""
	record_enter_when_ready = false
	review_grade_requested = false
	record_open_requested = false
	sync_screen_visibility()
	page_scroll.scroll_vertical = 0
	update_record_summary()

func enter_record_review() -> void:
	if pending:
		return
	home_section = "review"
	record_open_requested = true
	sync_screen_visibility()
	page_scroll.scroll_vertical = 0
	open_record_when_idle()

func start_record_review() -> void:
	if pending or state.is_empty() or state.moves.is_empty() or local_match_active():
		return
	if full_review.get("status", "") == "complete":
		enter_record_review()
		return
	record_error = ""
	record_enter_when_ready = true
	if full_review.get("status", "") == "running":
		return
	open_review_when_ready = false
	if offline_local:
		send("record-review-start", {"revision": int(state.revision), "setup": state.setup, "initialFen": state.initialFen, "moves": state.moves})
	else:
		send("review-start", {"revision": int(state.revision)})

func update_record_summary() -> void:
	if state.is_empty():
		return
	var identity := str(state.get("initialFen", "")) + JSON.stringify(state.moves)
	if not record_identity.is_empty() and record_identity != identity:
		full_review = {}
		record_enter_when_ready = false
	record_identity = identity
	var outcome: Dictionary = state.get("outcome", {})
	record_result.text = "진행 중인 경기"
	if outcome.get("over", false):
		record_result.text = "무승부" if outcome.get("winner") == null else ("초 승리" if outcome.winner == "cho" else "한 승리")
	record_details.text = "%s · %d수\n초 %s  vs  한 %s" % [str(outcome.get("reason", "기보 기록")) if outcome.get("over", false) else "현재까지의 기보", state.moves.size(), str(state.get("players", {}).get("cho", "초")), str(state.get("players", {}).get("han", "한"))]
	var phase := str(full_review.get("status", ""))
	var results: Array = full_review.get("results", [])
	for key in record_counts:
		var counts := {"cho": 0, "han": 0}
		for item in results:
			if item.get("classification", {}).get("key") == key and counts.has(item.get("side", "")):
				counts[item.side] += 1
		for team in ["cho", "han"]:
			record_counts[key][team].text = str(counts[team]) if phase in ["running", "complete"] else "—"
	record_progress.visible = phase == "running"
	record_progress.max_value = maxi(1, int(full_review.get("total", state.moves.size())))
	record_progress.value = int(full_review.get("completed", 0))
	record_start.text = "리뷰 시작"
	record_start.disabled = pending or local_match_active() or state.moves.is_empty() or phase == "running"
	record_browse.disabled = pending
	if not record_error.is_empty():
		record_status.text = record_error
		record_start.text = "분석 다시 시도"
	elif local_match_active():
		record_status.text = "대국이 끝나면 수 평가를 분석할 수 있습니다."
	elif state.moves.is_empty():
		record_status.text = "아직 분석할 수가 없습니다."
	elif phase == "running":
		record_status.text = "Stockfish 분석 중 · %d / %d수\n평가가 끝나면 리뷰 화면으로 이동합니다." % [int(full_review.completed), int(full_review.total)]
		record_start.text = "분석 중…"
	elif phase == "complete":
		record_status.text = "분석 완료 · %d수\n탁월수는 희생의 보상이 확인된 중요한 수입니다." % results.size()
	elif phase in ["failed", "cancelled", "error"]:
		record_status.text = "분석을 완료하지 못했습니다. 다시 시도해 주세요."
	else:
		record_status.text = "리뷰 시작을 누르면 Stockfish가 각 수를 분석합니다.\n분석 전 통계는 —로 표시됩니다." + ("\n기기 저장 경기의 분석에는 서버 연결이 필요합니다." if offline_local else "")

func open_record_when_idle() -> void:
	if pending or not record_open_requested:
		return
	record_open_requested = false
	clear_variation()
	show_review(0)
	review_grade_requested = false

func request_compact_analysis() -> void:
	if pending or offline_local or local_match_active() or state.moves.is_empty():
		return
	open_review_when_ready = false
	review_grade_requested = false
	send("review-start", {"revision": state.revision})

func reveal_home_control(control: Control) -> void:
	page_scroll.ensure_control_visible(control)

func toggle_server_controls() -> void:
	if current_role != "admin" or screen_mode != "home":
		return
	server_controls.visible = not server_controls.visible
	server_toggle.text = "서버 설정 접기" if server_controls.visible else "서버 기능 연결"

func toggle_game_setup() -> void:
	if screen_mode != "home":
		return
	if home_section == "setup":
		show_home_screen()
	else:
		show_home_setup(game_mode_tabs.current_tab)

func set_account_role(role: String) -> void:
	current_role = "admin" if role == "admin" else "user"
	account_badge.text = "관리자 계정 · 개발자 기능" if current_role == "admin" else "일반 사용자"
	if current_role != "admin":
		server_controls.visible = false
		server_toggle.text = "서버 기능 연결"
	sync_screen_visibility()

func show_home_screen() -> void:
	screen_mode = "home"
	home_section = "dashboard"
	record_open_requested = false
	review_grade_requested = false
	if not state.is_empty():
		return_live()
	sync_screen_visibility()
	page_scroll.scroll_vertical = 0

func show_game_screen() -> void:
	if state.is_empty():
		return
	screen_mode = "play"
	review = {}
	analysis_preview = {}
	variation = {}
	sync_screen_visibility()
	render_board()

func sync_screen_visibility() -> void:
	var playing := screen_mode == "play"
	var reviewing := not playing and home_section == "review"
	var recording := not playing and home_section == "record"
	record_panel.visible = recording
	app_background.color = Color("fff7e8")
	app_title.text = "경기 기록" if recording else ("게임 리뷰" if reviewing else ("고양이 장기 · 대국" if playing else "장기"))
	app_title.add_theme_color_override("font_color", Color("845847"))
	home_dashboard.visible = not playing and home_section == "dashboard"
	account_badge.visible = not playing and home_section == "dashboard" and current_role == "admin"
	home_button.visible = playing or reviewing or recording
	play_button.visible = false
	bottom_navigation.visible = not playing and not reviewing and not recording
	server_toggle.visible = not playing and home_section == "dashboard" and current_role == "admin"
	server_controls.visible = not playing and home_section == "dashboard" and current_role == "admin" and server_controls.visible
	status.visible = playing or current_role == "admin"
	game_setup_toggle.visible = not playing and home_section == "setup"
	game_setup_toggle.text = "메인으로 돌아가기"
	game_mode_tabs.visible = not playing and home_section == "setup"
	if playing:
		game_mode_tabs.visible = false
		game_setup_toggle.text = "새 대국 설정"
	review_tabs.visible = false
	message.visible = false
	compact_review_header.visible = reviewing
	compact_review_footer.visible = reviewing
	advantage_bar.visible = reviewing
	board_row.visible = playing or reviewing
	match_setup_panel.visible = playing
	last_move_panel.visible = playing
	score_panel.visible = playing
	clock_panel.visible = playing
	grid.visible = playing or reviewing
	board_credit.visible = playing
	game_actions.visible = playing

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
	var box := cream_box(background, Color.TRANSPARENT, 8, 0)
	box.content_margin_left = 2
	box.content_margin_right = 2
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box

func _ready() -> void:
	light_theme = create_app_theme()
	theme = light_theme
	app_background.color = Color("fff7e8")
	app_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(app_background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 14)
	add_child(margin)
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	page_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 12)
	margin.add_child(frame)
	frame.add_child(page_scroll)
	frame.add_child(bottom_navigation)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.add_child(column)
	app_title.text = "장기"
	app_title.add_theme_font_size_override("font_size", 30)
	app_title.add_theme_color_override("font_color", Color("845847"))
	column.add_child(app_title)
	var navigation := HFlowContainer.new()
	column.add_child(navigation)
	account_badge.text = "일반 사용자"
	navigation.add_child(account_badge)
	home_button.text = "메인으로"
	home_button.pressed.connect(show_home_screen)
	navigation.add_child(home_button)
	play_button.text = "대국 화면"
	play_button.pressed.connect(show_game_screen)
	navigation.add_child(play_button)
	home_dashboard.add_theme_constant_override("separation", 14)
	home_dashboard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(home_dashboard)
	var profile := PanelContainer.new()
	profile.add_theme_stylebox_override("panel", cream_box(Color("fff0dc")))
	home_dashboard.add_child(profile)
	var profile_row := HBoxContainer.new()
	profile_row.add_theme_constant_override("separation", 14)
	profile.add_child(profile_row)
	var avatar := Label.new()
	avatar.text = "將"
	avatar.add_theme_font_size_override("font_size", 34)
	avatar.add_theme_color_override("font_color", Color("b88768"))
	profile_row.add_child(avatar)
	var profile_text := Label.new()
	profile_text.text = "장기 플레이어\n기본 장기 · 오프라인 대국 가능"
	profile_text.add_theme_font_size_override("font_size", 17)
	profile_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_row.add_child(profile_text)
	var quick_heading := Label.new()
	quick_heading.text = "바로 시작"
	quick_heading.add_theme_font_size_override("font_size", 22)
	home_dashboard.add_child(quick_heading)
	var quick_grid := GridContainer.new()
	quick_grid.columns = 2
	quick_grid.add_theme_constant_override("h_separation", 10)
	quick_grid.add_theme_constant_override("v_separation", 10)
	home_dashboard.add_child(quick_grid)
	var ai_card := Button.new()
	ai_card.text = "AI 대전\n엔진과 실력 겨루기"
	ai_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_dashboard_button(ai_card)
	ai_card.pressed.connect(func(): call_deferred("show_home_setup", 0))
	quick_grid.add_child(ai_card)
	var local_card := Button.new()
	local_card.text = "로컬 2인\n한 기기에서 대국"
	local_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_dashboard_button(local_card)
	local_card.pressed.connect(func(): call_deferred("show_home_setup", 1))
	quick_grid.add_child(local_card)
	var stats_heading := Label.new()
	stats_heading.text = "현재 기록"
	stats_heading.add_theme_font_size_override("font_size", 22)
	home_dashboard.add_child(stats_heading)
	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", cream_box(Color("fffaf2")))
	home_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	home_stats.add_theme_font_size_override("font_size", 18)
	stats_panel.add_child(home_stats)
	home_dashboard.add_child(stats_panel)
	var recent_heading := Label.new()
	recent_heading.text = "경기 기록"
	recent_heading.add_theme_font_size_override("font_size", 22)
	home_dashboard.add_child(recent_heading)
	recent_game_button.custom_minimum_size.y = 105
	recent_game_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	recent_game_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recent_game_button.pressed.connect(func(): call_deferred("open_game_record"))
	home_dashboard.add_child(recent_game_button)
	primary_play.text = "대국 시작"
	style_dashboard_button(primary_play, true)
	primary_play.pressed.connect(func(): call_deferred("show_game_screen") if not state.is_empty() and not state.outcome.over else call_deferred("show_home_setup", 0))
	home_dashboard.add_child(primary_play)
	bottom_navigation.add_theme_constant_override("separation", 6)
	for caption in ["홈", "퍼즐", "학습", "더보기"]:
		var nav_button := Button.new()
		nav_button.text = caption
		nav_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav_button.custom_minimum_size.y = 58
		if caption == "홈":
			nav_button.pressed.connect(func(): call_deferred("show_home_screen"))
		else:
			nav_button.pressed.connect(func(): call_deferred("show_coming_soon"))
		bottom_navigation.add_child(nav_button)
	coming_soon.title = ""
	coming_soon.get_ok_button().text = "확인"
	add_child(coming_soon)
	endpoint.text = "http://127.0.0.1:3000"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--server="):
			endpoint.text = arg.trim_prefix("--server=")
		elif arg == "--role=admin":
			current_role = "admin"
	server_toggle.text = "서버 기능 연결"
	server_toggle.pressed.connect(toggle_server_controls)
	column.add_child(server_toggle)
	server_controls.add_theme_constant_override("separation", 8)
	server_controls.visible = false
	column.add_child(server_controls)
	server_controls.add_child(endpoint)
	var connect_button := Button.new()
	connect_button.text = "서버 연결 / 다시 시도"
	connect_button.pressed.connect(func(): request_state())
	server_controls.add_child(connect_button)
	status.text = "서버에 연결 중…"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	match_setup_panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(match_setup_panel)
	last_move_panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(last_move_panel)
	score_panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(score_panel)
	evaluation_graph.ply_selected.connect(show_review)
	review_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	review_method_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game_setup_toggle.text = "대국 설정 접기"
	game_setup_toggle.pressed.connect(toggle_game_setup)
	column.add_child(game_setup_toggle)
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
	ai_difficulty.add_item("빠르게 · 약 0.1초")
	ai_difficulty.add_item("보통 · 약 0.3초")
	ai_difficulty.add_item("강하게 · 약 1초")
	ai_difficulty.select(1)
	ai_game_panel.add_child(ai_difficulty)
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
	column.add_child(record_panel)
	record_panel.add_theme_constant_override("separation", 16)
	record_result.add_theme_font_size_override("font_size", 30)
	record_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	record_panel.add_child(record_result)
	record_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	record_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	record_panel.add_child(record_details)
	var stats_card := PanelContainer.new()
	stats_card.add_theme_stylebox_override("panel", cream_box(Color("fffaf2")))
	record_panel.add_child(stats_card)
	var stats := GridContainer.new()
	stats.columns = 3
	stats.add_theme_constant_override("v_separation", 16)
	stats_card.add_child(stats)
	for caption in ["수 평가", "초", "한"]:
		var heading := Label.new()
		heading.text = caption
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.add_child(heading)
	var grades := {"brilliant": "탁월수", "best": "최선수", "good": "좋은 수", "inaccuracy": "부정확한 수", "mistake": "실수", "blunder": "큰 실수", "unclassified": "평가 제외"}
	for key in grades:
		var caption := Label.new()
		caption.text = grades[key]
		stats.add_child(caption)
		record_counts[key] = {}
		for team in ["cho", "han"]:
			var count := Label.new()
			count.text = "—"
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count.add_theme_font_size_override("font_size", 24)
			count.add_theme_color_override("font_color", Color("5782b5") if team == "cho" else Color("b46955"))
			stats.add_child(count)
			record_counts[key][team] = count
	record_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	record_panel.add_child(record_status)
	record_panel.add_child(record_progress)
	style_dashboard_button(record_start, true)
	record_start.pressed.connect(start_record_review)
	record_panel.add_child(record_start)
	record_browse.text = "기보만 보기"
	record_browse.custom_minimum_size.y = 48
	record_browse.pressed.connect(enter_record_review)
	record_panel.add_child(record_browse)
	compact_review_header.add_theme_constant_override("separation", 8)
	column.add_child(compact_review_header)
	compact_grade.add_theme_font_size_override("font_size", 26)
	compact_grade.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	compact_review_header.add_child(compact_grade)
	compact_advantage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	compact_review_header.add_child(compact_advantage)
	grid.columns = 9
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_row.add_theme_constant_override("separation", 10)
	column.add_child(board_row)
	board_row.add_child(advantage_bar)
	var board_stack := MarginContainer.new()
	board_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_row.add_child(board_stack)
	board_stack.add_child(grid)
	board_stack.add_child(review_overlay)
	review_overlay.board = grid
	grid.sort_children.connect(review_overlay.queue_redraw)
	column.add_child(compact_review_footer)
	compact_review_footer.add_theme_constant_override("separation", 8)
	compact_move.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compact_move.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	compact_review_footer.add_child(compact_move)
	var review_steps := HBoxContainer.new()
	compact_review_footer.add_child(review_steps)
	compact_previous.text = "‹ 이전 수"
	compact_next.text = "다음 수 ›"
	for step_button in [compact_previous, compact_next]:
		step_button.custom_minimum_size.y = 56
		step_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		review_steps.add_child(step_button)
	compact_previous.pressed.connect(func(): show_review(view_ply() - 1))
	compact_next.pressed.connect(func(): show_review(view_ply() + 1))
	compact_resume.text = "재개"
	compact_resume.custom_minimum_size.y = 56
	compact_resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compact_resume.pressed.connect(resume_review)
	review_steps.add_child(compact_resume)
	compact_analyze.text = "수 평가 다시 분석"
	compact_analyze.pressed.connect(request_compact_analysis)
	compact_review_footer.add_child(compact_analyze)
	board_credit.bbcode_enabled = true
	board_credit.fit_content = true
	board_credit.add_theme_color_override("default_color", Color("786957"))
	board_credit.text = "[font_size=12]장기말 · [url=https://github.com/Kadagaden/chess-pieces]Kadagaden / chess-pieces[/url] · [url=https://creativecommons.org/licenses/by/4.0/]CC BY 4.0[/url][/font_size]"
	board_credit.meta_clicked.connect(func(url): OS.shell_open(str(url)))
	column.add_child(board_credit)
	column.add_child(game_actions)
	add_action(game_actions, "한수쉼", pass_turn)
	add_action(game_actions, "무르기", func(): act("undo"))
	add_action(game_actions, "AI 취소", func(): act("cancel-ai"))
	add_action(game_actions, "AI 재개", func(): act("resume-ai"))
	resign_button.text = "기권"
	resign_button.custom_minimum_size.y = 44
	resign_button.pressed.connect(func(): resign_dialog.popup_centered())
	game_actions.add_child(resign_button)
	draw_button.text = "합의 무승부"
	draw_button.custom_minimum_size.y = 44
	draw_button.pressed.connect(func(): draw_dialog.popup_centered())
	game_actions.add_child(draw_button)
	rematch_button.text = "같은 설정 재대국"
	rematch_button.custom_minimum_size.y = 44
	rematch_button.pressed.connect(func(): open_new_game_dialog(str(state.get("mode", "local"))))
	game_actions.add_child(rematch_button)
	device_recommend.text = "기기 추천"
	device_recommend.custom_minimum_size.y = 44
	device_recommend.pressed.connect(start_device_recommendation)
	game_actions.add_child(device_recommend)
	device_cancel.text = "추천 취소"
	device_cancel.custom_minimum_size.y = 44
	device_cancel.pressed.connect(cancel_device_recommendation)
	game_actions.add_child(device_cancel)
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
	new_game_dialog.title = "새 대국 확인"
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
	resign_dialog.title = "기권 확인"
	resign_dialog.get_ok_button().text = "기권"
	resign_dialog.get_cancel_button().text = "취소"
	resign_dialog.confirmed.connect(func(): act("resign", {"side": state.get("turn", "cho")}))
	add_child(resign_dialog)
	draw_dialog.dialog_text = "양쪽이 합의한 무승부로 대국을 종료할까요?"
	draw_dialog.title = "무승부 확인"
	draw_dialog.get_ok_button().text = "무승부"
	draw_dialog.get_cancel_button().text = "취소"
	draw_dialog.confirmed.connect(func(): act("draw"))
	add_child(draw_dialog)
	api.timeout = 8.0
	api.request_completed.connect(on_response)
	add_child(api)
	branch_api.timeout = 20.0
	branch_api.request_completed.connect(on_branch_response)
	add_child(branch_api)
	timer.wait_time = 0.5
	timer.timeout.connect(request_state)
	add_child(timer)
	timer.start()
	set_account_role(current_role)
	render_board()
	if not load_offline_local():
		request_state()
	else:
		screen_mode = "home"
		sync_screen_visibility()

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
	game_mode_tabs.visible = false
	game_setup_toggle.text = "새 대국 설정"
	ai_difficulty.select(maxi(["quick", "normal", "strong"].find(str(state.get("aiLevel", "normal"))), 0))
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

func selected_ai_level() -> String:
	return ["quick", "normal", "strong"][clampi(ai_difficulty.selected, 0, 2)]

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
		"revision": revision, "variant": "janggi", "mode": "local", "humanSide": "cho", "aiLevel": "normal",
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
	screen_mode = "play"
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
		game_mode_tabs.visible = false
		game_setup_toggle.text = "새 대국 설정"
		sync_screen_visibility()

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
	screen_mode = "play"
	sync_screen_visibility()
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
		"aiLevel": selected_ai_level(),
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
	if not pending and full_review.get("status", "") == "running" and full_review.has("recordJobId"):
		send("record-review-status", {"recordJobId": full_review.recordJobId})
		return
	if record_open_requested:
		open_record_when_idle()
		return
	if review_grade_requested and not pending:
		request_compact_analysis()
		return
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
		if path.begins_with("record-review") or (home_section == "record" and path == "review-start"):
			record_error = message.text
			full_review = {}
		render_board()

func on_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	pending = false
	endpoint.editable = true
	var parser := JSON.new()
	if result != HTTPRequest.RESULT_SUCCESS or parser.parse(body.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		message.text = "서버에 연결하지 못했습니다. 서버 실행과 주소를 확인하세요."
		if current_path.begins_with("record-review") or (home_section == "record" and current_path in ["review-start", "review-status"]):
			record_error = "분석 서버에 연결하지 못했습니다. 연결 후 다시 시도해 주세요."
			full_review = {}
		render_board()
		return
	var payload: Dictionary = parser.data
	if code != 200:
		message.text = str(payload.get("error", "요청 실패"))
		if current_path.begins_with("record-review") or (home_section == "record" and current_path in ["review-start", "review-status"]):
			record_error = message.text
			full_review = {}
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
			apply_branch_selection()
		render_board()
		return
	if current_path in ["review-start", "review-status", "review-latest", "review-cancel", "record-review-start", "record-review-status"]:
		if current_path == "review-latest" and payload.get("status", "") == "none":
			import_full_review(false)
			render_board()
			return
		if not payload.has("jobId") or not payload.has("status") or not payload.has("completed") or not payload.has("total"):
			message.text = "전체 리뷰 응답 형식이 올바르지 않습니다."
		else:
			full_review = payload
			if int(payload.get("policyVersion", 0)) != 2:
				full_review = {}
				record_error = "수 평가 기준이 변경되었습니다. 서버 업데이트 후 다시 분석해 주세요."
				render_board()
				return
			if payload.status == "running":
				message.text = "전체 리뷰 분석 중 · %d/%d수" % [int(payload.completed), int(payload.total)]
			elif payload.status == "complete":
				message.text = "전체 리뷰 완료 · %d수" % int(payload.total)
				evaluation_graph.set_results(payload.results)
				review_summary.text = format_review_summary(payload.get("summary", {}))
				export_full_review(false)
				if record_enter_when_ready and home_section == "record":
					record_enter_when_ready = false
					call_deferred("enter_record_review")
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
	if changed or current_path != "game" or home_section == "record":
		render_board()
	if pending_ai_start_after_connect:
		pending_ai_start_after_connect = false
		act("reset", {
			"mode": "ai", "humanSide": "cho" if side.selected == 0 else "han",
			"aiLevel": selected_ai_level(),
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
	if int(imported_review.get("policyVersion", 0)) != 2:
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
	if not classification.get("key", "") in ["brilliant", "best", "excellent", "good", "inaccuracy", "mistake", "blunder", "unclassified"] or str(classification.get("label", "")) == "":
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
	apply_branch_selection()
	render_board()

func apply_branch_selection() -> void:
	if branch_first_square == "":
		return
	var square := branch_first_square
	var piece := branch_first_piece
	branch_first_square = ""
	branch_first_piece = ""
	choose(square, piece)

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
	branch_api.cancel_request()
	branch_busy = false
	branch_fen = ""
	branch_moves = []
	branch_entry = {}
	branch_error = ""
	branch_first_square = ""
	variation_evaluation_target = ""
	variation_evaluation = {}
	variation = {}
	variation_start_ply = -1
	variation_moves = []

func schedule_variation_evaluation() -> void:
	branch_api.cancel_request()
	branch_entry = {}
	branch_error = ""
	variation_evaluation = {}
	variation_evaluation_target = ""
	branch_fen = str(variation.get("fen", ""))
	branch_moves = variation.get("moves", []).duplicate()
	branch_busy = true
	var url := endpoint.text.strip_edges().trim_suffix("/")
	var error := branch_api.request(url + "/api/review-position", ["Content-Type: application/json"], HTTPClient.METHOD_POST,
		JSON.stringify({"initialFen": variation.initialFen, "moves": branch_moves, "revision": state.revision}))
	if error != OK:
		branch_busy = false
		branch_error = "분석 서버에 연결하지 못했습니다."

func on_branch_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	branch_busy = false
	if variation.is_empty() or variation.fen != branch_fen or variation.moves != branch_moves:
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not payload is Dictionary:
		branch_error = "분석 연결 실패 · 다시 두거나 재개해 주세요."
	else:
		if payload.get("fen", "") != branch_fen or payload.get("moves", []) != branch_moves:
			return
		branch_entry = payload.entry if payload.get("entry") is Dictionary and not variation_moves.is_empty() else {}
		variation_evaluation = payload.evaluation if payload.get("evaluation") is Dictionary else terminal_evaluation(payload.get("outcome", {}))
	render_board()

func terminal_evaluation(outcome: Dictionary) -> Dictionary:
	if not outcome.get("over", false):
		return {}
	if outcome.get("winner") == null:
		return {"unit": "cp", "cho": 0}
	return {"unit": "mate", "cho": 1 if outcome.winner == "cho" else -1}

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
	if full_review.get("status", "") not in ["complete", "running"]:
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
	if pending:
		return
	if not review.is_empty() and variation.is_empty():
		if home_section != "review" or local_match_active() or review.get("outcome", {}).get("over", false):
			return
		var own_piece: bool = piece != "" and ((piece == piece.to_upper()) == (review.turn == "cho"))
		if not own_piece:
			return
		branch_first_square = square
		branch_first_piece = piece
		start_variation()
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
	update_compact_review()

func update_compact_review() -> void:
	update_record_summary()
	recent_game_button.disabled = state.is_empty()
	recent_game_button.text = home_recent_text + ("\n기보 보기  ›" if not state.is_empty() else "")
	primary_play.text = "이어서 대국" if not state.is_empty() and not state.outcome.over else "새 대국 시작"
	var ply := view_ply()
	var total: int = state.get("moves", []).size()
	compact_previous.disabled = pending or review.is_empty() or ply <= 0
	compact_next.disabled = pending or review.is_empty() or ply >= total
	var branching := not variation.is_empty()
	compact_previous.visible = not branching
	compact_next.visible = not branching
	compact_resume.visible = branching
	compact_resume.disabled = pending
	compact_move.text = "시작 배치 · 0 / %d수" % total if ply == 0 else "%s · %d / %d수" % [readable_move(str(state.moves[ply - 1])), ply, total]
	var entry := branch_entry if branching else cached_review_result(ply)
	var labels := {"brilliant": "탁월", "best": "최선", "excellent": "정확", "good": "좋은 수", "inaccuracy": "부정확", "mistake": "실수", "blunder": "큰 실수", "unclassified": "평가 제외"}
	compact_grade.text = "시작 배치" if ply == 0 else str(labels.get(entry.get("classification", {}).get("key", ""), "미분석"))
	if branching:
		compact_move.text = "직접 두기 · %d수에서 %d수 진행" % [variation_start_ply, variation_moves.size()]
		compact_grade.text = "분석 중…" if branch_busy else str(labels.get(entry.get("classification", {}).get("key", ""), "직접 두기"))
	compact_grade.add_theme_color_override("font_color", Color("b46955") if entry.get("classification", {}).get("key", "") in ["inaccuracy", "mistake", "blunder"] else Color("6c8060"))
	var evaluation := variation_evaluation if branching else compact_evaluation(entry, "after")
	if not branching and ply == 0:
		evaluation = compact_evaluation(cached_review_result(1), "before")
	elif not branching and ply == total and not state.is_empty() and state.outcome.over:
		evaluation = terminal_evaluation(state.outcome)
	var before := compact_evaluation(entry, "before")
	var flipped: bool = state.get("mode", "") == "ai" and state.get("humanSide", "") == "han"
	advantage_bar.set_evaluation(evaluation, flipped, before)
	compact_advantage.text = branch_error if branching else ""
	compact_advantage.visible = compact_advantage.text != ""
	var grade := str(entry.get("classification", {}).get("key", ""))
	var played := split_move(str(entry.get("playedMove", "")))
	var arrow := str(entry.get("recommendedMove", "")) if grade not in ["", "best", "brilliant"] else ""
	review_overlay.visible = screen_mode == "home" and home_section == "review"
	review_overlay.set_markers(arrow, played[1] if played.size() == 2 else "", grade)
	review_overlay.tooltip_text = "초록 화살표: 직전 위치에서의 최선 수"
	compact_analyze.visible = not branching and not offline_local and not local_match_active() and total > 0 and full_review.get("status", "") not in ["running", "complete"]
	compact_analyze.disabled = pending

func compact_evaluation(entry: Dictionary, phase: String) -> Dictionary:
	var result: Variant = entry.get("analysis", {}).get(phase)
	if not result is Dictionary or not result.get("evaluation") is Dictionary:
		return {}
	return result.evaluation

func readable_move(move: String) -> String:
	var pair := split_move(move)
	if pair.size() != 2:
		return move
	return "한수쉼" if pair[0] == pair[1] else "%s → %s" % [pair[0], pair[1]]

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
		home_stats.text = "아직 진행 중인 대국이 없습니다."
		home_recent_text = "새 대국을 시작하면 최근 진행 상황이 여기에 표시됩니다."
		match_setup_panel.text = ""
		last_move_panel.text = ""
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
	var live_last_move := ""
	if screen_mode == "play" and review.is_empty() and variation.is_empty() and analysis_preview.is_empty() and not state.moves.is_empty():
		live_last_move = str(state.moves[-1])
	elif home_section == "review" and not state.moves.is_empty():
		live_last_move = str(state.moves[-1])
	var live_last_pair := split_move(live_last_move)
	for row in range(10):
		for file in range(9):
			var square := String.chr(97 + (8 - file if flipped else file)) + str(row + 1 if flipped else 10 - row)
			var piece: String = pieces.get(square, "")
			var button := Button.new()
			button.text = ""
			button.tooltip_text = square
			button.custom_minimum_size = Vector2(40, maxf(40.0, grid.size.x / 9.0))
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.size_flags_vertical = Control.SIZE_EXPAND_FILL
			for style in ["normal", "disabled", "hover", "pressed"]:
				button.add_theme_stylebox_override(style, board_box(Color.TRANSPARENT))
			button.add_theme_stylebox_override("hover", board_box(Color(1, 1, 1, 0.3)))
			if piece != "":
				var names := {"k": "king", "a": "advisor", "r": "chariot", "n": "horse", "b": "elephant", "c": "cannon", "p": "pawn"}
				var color := "blue" if piece == piece.to_upper() else "red"
				var art := TextureRect.new()
				art.name = "PieceArt"
				art.texture = load("res://assets/janggi/%s_%s.svg" % [color, names[piece.to_lower()]])
				art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				art.mouse_filter = Control.MOUSE_FILTER_IGNORE
				button.add_child(art)
				art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				art.offset_left = 2
				art.offset_top = 2
				art.offset_right = -2
				art.offset_bottom = -2
			button.add_theme_color_override("font_color", Color("5687a0") if piece != "" and piece == piece.to_upper() else Color("c8796d") if piece != "" else Color("ccb8a6"))
			button.add_theme_color_override("font_disabled_color", Color("6f9aaf") if piece != "" and piece == piece.to_upper() else Color("ce8b81") if piece != "" else Color("cfbdad"))
			if live_last_pair.size() == 2 and square == live_last_pair[0]:
				button.modulate = Color("ffd36f")
			elif live_last_pair.size() == 2 and square == live_last_pair[1]:
				button.modulate = Color("ff9f80")
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
			if button.modulate != Color.WHITE:
				button.self_modulate = button.modulate
				button.modulate = Color.WHITE
				for style in ["normal", "disabled", "hover", "pressed"]:
					button.add_theme_stylebox_override(style, board_box(Color(1, 1, 1, 0.72)))
			var interactive_review := screen_mode == "home" and home_section == "review" and not local_match_active()
			button.disabled = (not review.is_empty() and variation.is_empty() and not interactive_review) or (pending and current_path != "game") or (ai_turn and not interactive_review) or state.outcome.over
			button.pressed.connect(choose.bind(square, piece))
			grid.add_child(button)
			squares[square] = button
	var players: Dictionary = state.get("players", {"cho": "초", "han": "한"})
	var setup: Dictionary = state.get("setup", {})
	match_setup_panel.text = "기물 배치 · 초 %s / 한 %s" % [arrangement_label(str(setup.get("cho", "nbbn"))), arrangement_label(str(setup.get("han", "nbbn")))]
	last_move_panel.text = ""
	if live_last_pair.size() == 2:
		var moved_side := "초" if state.moves.size() % 2 == 1 else "한"
		var destination_piece: String = str(pieces.get(live_last_pair[1], ""))
		var piece_name := "병" if destination_piece == "p" else str(labels.get(destination_piece.to_lower(), "기물"))
		last_move_panel.text = "직전 착수 · %s %s · 노란 출발칸 → 주황 도착칸" % [moved_side, piece_name]
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
	var mode_name := "로컬 2인" if state.get("mode", "") == "local" else "AI 대전"
	var turn_name := "초" if state.turn == "cho" else "한"
	home_stats.text = "%d수 진행  ·  초 %.1f  ·  한 %.1f\n%s · %s" % [state.moves.size(), cho_points, han_points, mode_name, "대국 종료" if state.outcome.over else turn_name + " 차례"]
	if state.outcome.over:
		var home_result := "무승부" if state.outcome.get("winner") == null else ("초 승리" if state.outcome.winner == "cho" else "한 승리")
		home_recent_text = "%s  ·  %s\n%d수 · %s" % [mode_name, home_result, state.moves.size(), str(state.outcome.get("reason", "종료"))]
	else:
		home_recent_text = "%s  ·  %s 차례\n%d수까지 진행" % [mode_name, turn_name, state.moves.size()]
	if not variation.is_empty():
		if variation_evaluation.is_empty():
			score_panel.text += " · 기기 형세 계산 중…" if device_engine.available() else " · 기기 형세 사용 불가"
		elif variation_evaluation.unit == "cp":
			score_panel.text += " · 초 %+.0fcp" % float(variation_evaluation.cho)
		else:
			score_panel.text += " · 기기 고전평가 강제승패 %s" % str(variation_evaluation.cho)
	for button in action_buttons:
		button.disabled = not review.is_empty() or (pending and current_path != "game")
	var local_mode: bool = self.state.get("mode", "") == "local"
	action_buttons[1].visible = not self.state.outcome.over
	action_buttons[3].visible = not local_mode
	action_buttons[4].visible = not local_mode
	action_buttons[1].disabled = action_buttons[1].disabled or ai_turn or state.outcome.over or state.inCheck
	action_buttons[2].disabled = action_buttons[2].disabled or not state.canUndo
	action_buttons[3].disabled = action_buttons[3].disabled or state.ai.status != "thinking"
	action_buttons[4].disabled = action_buttons[4].disabled or not state.ai.status in ["paused", "error"]
	device_recommend.disabled = local_match_active() or not variation.is_empty() or not device_engine.available() or device_engine.busy() or state.outcome.over or state.legalMoves.is_empty()
	device_cancel.disabled = not variation.is_empty() or not device_engine.busy()
	device_recommend.visible = not local_mode or not review.is_empty()
	device_cancel.visible = not local_mode or not review.is_empty()
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
	resign_button.visible = local_match_active()
	draw_button.visible = local_match_active()
	rematch_button.visible = local_mode and self.state.outcome.over
	sync_screen_visibility()
