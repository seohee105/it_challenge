extends Control

# 다이어리 왼쪽 페이지 = 운동 종류를 골라 바로 추가하는 곳 (기존 AddExercise 화면 역할)
# / 항목을 누르면 같은 자리에서 시간재기 화면으로 바뀐다 (기존 ExerciseTimer 화면 역할)
@onready var left_pages: Control = $LeftCardRoot/ContentMargin/LeftPages
@onready var category_view: Control = $LeftCardRoot/ContentMargin/LeftPages/CategoryView
@onready var category_container: VBoxContainer = $LeftCardRoot/ContentMargin/LeftPages/CategoryView/ScrollContainer/CategoryContainer
@onready var left_msg_label: Label = $LeftCardRoot/ContentMargin/LeftPages/CategoryView/MsgLabel

@onready var timer_view: Control = $LeftCardRoot/ContentMargin/LeftPages/TimerView
@onready var timer_icon: TextureRect = $LeftCardRoot/ContentMargin/LeftPages/TimerView/TimerIcon
@onready var timer_name_label: Label = $LeftCardRoot/ContentMargin/LeftPages/TimerView/TimerNameLabel
@onready var timer_time_label: Label = $LeftCardRoot/ContentMargin/LeftPages/TimerView/TimerTimeLabel
@onready var timer_play_button: Button = $LeftCardRoot/ContentMargin/LeftPages/TimerView/TimerControlButtons/TimerPlayButton
@onready var timer_stop_button: Button = $LeftCardRoot/ContentMargin/LeftPages/TimerView/TimerControlButtons/TimerStopButton
@onready var timer_back_button: Button = $LeftCardRoot/ContentMargin/LeftPages/TimerView/TimerBackButton

# 다이어리 오른쪽 페이지 = 지금까지 추가한 운동 기록 목록 (기존 Home 화면 역할)
@onready var item_container: VBoxContainer = $RightCardRoot/ContentMargin/VBox/ScrollContainer/ItemContainer
@onready var today_cal_label: Label = $RightCardRoot/ContentMargin/VBox/TodayCalLabel
@onready var edit_toggle_button: Button = $RightCardRoot/ContentMargin/VBox/BottomBar/EditDeleteButton

@onready var side_actions: Panel = $SideActions
@onready var side_delete: Button = $SideActions/VBox/DeleteButton
@onready var side_edit: Button = $SideActions/VBox/EditButton
@onready var side_edit_line: LineEdit = $SideActions/VBox/EditLine
@onready var side_save: Button = $SideActions/VBox/SaveEditButton
@onready var side_cancel: Button = $SideActions/VBox/CancelEditButton

# 운동 종류 버튼 옆에 붙일 귀여운 이모지 (ExerciseData의 카테고리 이름 자체는
# 캘린더 등 다른 화면에서도 쓰이므로 건드리지 않고, 이 화면에서만 붙인다)
const CATEGORY_EMOJI := {
	"hometraining": "🏠",
	"outdoor_cardio": "🌳",
	"gym": "💪",
	"yoga_pilates": "🧘",
	"pt": "🥊",
	"sports": "⚽",
	"other_cardio": "🚴",
	"other_strength": "🏋️",
	"other_functional": "🤸",
	"other_hiit": "🔥",
}

var edit_mode: bool = false
var selected_item: Dictionary = {}
var editing_item_id: String = ""
var custom_row_controls: Dictionary = {}

# ----- 왼쪽 페이지: 시간재기(타이머) 상태 -----
var timer_current_item: Dictionary = {}
var timer_is_running: bool = false


func _ready() -> void:
	edit_toggle_button.pressed.connect(_on_edit_toggle)
	side_delete.pressed.connect(_on_side_delete)
	side_edit.pressed.connect(_on_side_edit)
	side_save.pressed.connect(_on_side_save)
	side_cancel.pressed.connect(_on_side_cancel)

	timer_play_button.pressed.connect(_on_timer_play_pressed)
	timer_stop_button.pressed.connect(_on_timer_stop_pressed)
	timer_back_button.pressed.connect(_on_timer_back_pressed)

	for cat in ExerciseData.CATEGORIES:
		_add_category_row(cat)

	refresh_list()

	# 앱을 종료했다가 다시 켰는데 진행 중이던 타이머가 있으면 바로 이어서 볼 수 있게 함
	if not SessionManager.active_timer.is_empty():
		_open_timer_view({
			"item_id": SessionManager.active_timer.item_id,
			"category_id": SessionManager.active_timer.category_id,
			"custom_label": SessionManager.active_timer.custom_label,
		})


func _process(_delta: float) -> void:
	if timer_view.visible and timer_is_running:
		_update_timer_label()


# ----- 왼쪽 페이지: 운동 종류 선택 -----

func _add_category_row(cat: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var icon_rect := TextureRect.new()
	icon_rect.texture = ExerciseData.get_icon(cat.id)
	icon_rect.custom_minimum_size = Vector2(30, 30)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon_rect)

	var emoji: String = CATEGORY_EMOJI.get(cat.id, "🏃")
	var btn := Button.new()
	btn.text = "%s %s" % [emoji, cat.name]
	btn.custom_minimum_size = Vector2(0, 52)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 18)
	row.add_child(btn)

	var line_edit: LineEdit = null
	if cat.is_custom:
		line_edit = LineEdit.new()
		line_edit.placeholder_text = cat.examples
		line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line_edit.visible = false
		row.add_child(line_edit)

		var confirm_button := Button.new()
		confirm_button.text = "✅ 확인"
		confirm_button.custom_minimum_size = Vector2(84, 0)
		confirm_button.visible = false
		confirm_button.pressed.connect(_on_confirm_pressed.bind(cat, line_edit))
		row.add_child(confirm_button)

		line_edit.focus_entered.connect(func():
			confirm_button.visible = true
		)

		custom_row_controls[cat.id] = {
			"line_edit": line_edit,
			"confirm_button": confirm_button,
		}

	btn.pressed.connect(_on_category_pressed.bind(cat, line_edit))
	category_container.add_child(row)


func _on_category_pressed(cat: Dictionary, line_edit: LineEdit) -> void:
	if not cat.is_custom:
		_add_home_item_if_valid(cat, "", line_edit)
		return

	if line_edit == null:
		return

	var controls: Dictionary = custom_row_controls.get(cat.id, {})
	var is_visible := line_edit.visible
	line_edit.visible = not is_visible
	var confirm_button: Button = null
	if controls.has("confirm_button"):
		confirm_button = controls["confirm_button"]
	if confirm_button != null:
		confirm_button.visible = not is_visible
	if line_edit.visible:
		line_edit.grab_focus()


func _on_confirm_pressed(cat: Dictionary, line_edit: LineEdit) -> void:
	if not cat.is_custom or line_edit == null:
		return
	var custom_label := line_edit.text.strip_edges()
	if custom_label == "":
		line_edit.placeholder_text = "운동 이름을 입력해주세요"
		line_edit.grab_focus()
		return

	_add_home_item_if_valid(cat, custom_label, line_edit)
	line_edit.grab_focus()


func _add_home_item_if_valid(cat: Dictionary, custom_label: String, line_edit: LineEdit) -> void:
	for item in SessionManager.home_items:
		if item.category_id == cat.id:
			if cat.is_custom and item.custom_label == custom_label:
				_show_temp_message("이미 추가한 운동이에요 🙂", 0.8)
				return
			if not cat.is_custom:
				_show_temp_message("이미 추가한 운동이에요 🙂", 0.8)
				return

	SessionManager.add_home_item(cat.id, custom_label)
	SessionManager.save_data()
	if line_edit:
		line_edit.text = ""
		line_edit.visible = false
	_show_temp_message("✨ 운동을 추가했어요!", 0.8)
	refresh_list()


func _show_temp_message(msg: String, dur: float = 0.5) -> void:
	left_msg_label.text = msg
	left_msg_label.visible = true
	await get_tree().create_timer(dur).timeout
	left_msg_label.visible = false


# ----- 오른쪽 페이지: 운동 기록 목록 -----

func _format_seconds(sec: int) -> String:
	var h := sec / 3600
	var m := (sec % 3600) / 60
	var s := sec % 60
	return "%d:%02d:%02d" % [h, m, s]


func refresh_list() -> void:
	for c in item_container.get_children():
		c.queue_free()

	var today_total := 0.0
	for item in SessionManager.home_items:
		var cat: Dictionary = ExerciseData.get_category(item.category_id)
		var label_text: String = item.custom_label if item.custom_label != "" else cat.name
		var emoji: String = CATEGORY_EMOJI.get(item.category_id, "🏃")
		var stats := _get_item_stats(item)
		today_total += stats.total_cal

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0, 84)
		row.add_theme_constant_override("separation", 14)

		var icon_rect := TextureRect.new()
		icon_rect.texture = ExerciseData.get_icon(item.category_id)
		icon_rect.custom_minimum_size = Vector2(34, 34)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon_rect)

		var btn := Button.new()
		btn.text = "%s %s" % [emoji, label_text]
		btn.add_theme_font_size_override("font_size", 18)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 84)

		if edit_mode:
			btn.pressed.connect(_on_item_selected_for_edit.bind(item))
		else:
			btn.pressed.connect(_on_item_pressed.bind(item))

		row.add_child(btn)

		var right_v := VBoxContainer.new()
		right_v.size_flags_horizontal = Control.SIZE_SHRINK_END
		right_v.custom_minimum_size = Vector2(150, 0)
		right_v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		right_v.add_theme_constant_override("separation", 4)

		var time_label := Label.new()
		time_label.text = "⏱ " + _format_seconds(stats.total_sec)
		time_label.add_theme_font_size_override("font_size", 16)
		var cal_label := Label.new()
		cal_label.text = "🔥 %.1f kcal" % [stats.total_cal]
		cal_label.add_theme_font_size_override("font_size", 16)
		right_v.add_child(time_label)
		right_v.add_child(cal_label)

		if edit_mode:
			var actions := HBoxContainer.new()
			actions.size_flags_horizontal = Control.SIZE_SHRINK_END
			actions.add_theme_constant_override("separation", 6)

			var delete_button := Button.new()
			delete_button.text = "🗑 삭제"
			delete_button.pressed.connect(_on_row_delete.bind(item))
			actions.add_child(delete_button)

			if cat.is_custom:
				var edit_button := Button.new()
				edit_button.text = "✏️ 수정"
				edit_button.pressed.connect(_on_row_edit.bind(item))
				actions.add_child(edit_button)

			right_v.add_child(actions)

			if editing_item_id == item.item_id:
				var edit_line := LineEdit.new()
				edit_line.text = item.custom_label
				edit_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				right_v.add_child(edit_line)

				var edit_actions := HBoxContainer.new()
				edit_actions.size_flags_horizontal = Control.SIZE_SHRINK_END
				edit_actions.add_theme_constant_override("separation", 6)

				var save_button := Button.new()
				save_button.text = "💾 저장"
				save_button.pressed.connect(_on_row_save.bind(item, edit_line))
				edit_actions.add_child(save_button)

				var cancel_button := Button.new()
				cancel_button.text = "취소"
				cancel_button.pressed.connect(_on_row_cancel)
				edit_actions.add_child(cancel_button)

				right_v.add_child(edit_actions)

		row.add_child(right_v)
		item_container.add_child(row)

	today_cal_label.text = "🔥 오늘의 총 소모 칼로리: %.1f kcal" % [today_total]


func _get_item_stats(item: Dictionary) -> Dictionary:
	var total_sec := 0
	var total_cal := 0.0
	for r in SessionManager.sessions:
		if r.category_id == item.category_id and r.custom_label == item.custom_label:
			total_sec += int(r.duration_min * 60.0)
			total_cal += float(r.calories)
	return {"total_sec": total_sec, "total_cal": total_cal}


func _on_item_pressed(item: Dictionary) -> void:
	_open_timer_view(item)


# ----- 왼쪽 페이지: 시간재기(타이머) 화면 -----

func _open_timer_view(item: Dictionary) -> void:
	timer_current_item = item
	var cat: Dictionary = ExerciseData.get_category(item.category_id)
	var emoji: String = CATEGORY_EMOJI.get(item.category_id, "🏃")
	var label_text: String = item.custom_label if item.custom_label != "" else cat.name
	timer_name_label.text = "%s %s" % [emoji, label_text]
	timer_icon.texture = ExerciseData.get_icon(item.category_id)

	if not SessionManager.active_timer.is_empty() \
			and SessionManager.active_timer.item_id == item.item_id:
		if SessionManager.active_timer.paused:
			timer_is_running = false
			timer_play_button.text = "▶"
		else:
			timer_is_running = true
			timer_play_button.text = "⏸"
		timer_stop_button.disabled = false
		_update_timer_label()
	else:
		timer_is_running = false
		timer_play_button.text = "▶"
		timer_stop_button.disabled = true
		var total_sec := 0
		for r in SessionManager.sessions:
			if r.category_id == item.category_id and r.custom_label == item.custom_label:
				total_sec += int(r.duration_min * 60.0)
		timer_time_label.text = _format_seconds(total_sec)

	category_view.visible = false
	timer_view.visible = true


func _close_timer_view() -> void:
	timer_view.visible = false
	category_view.visible = true
	timer_current_item = {}
	timer_is_running = false


func _update_timer_label() -> void:
	timer_time_label.text = _format_seconds(SessionManager.get_elapsed_seconds())


func _on_timer_play_pressed() -> void:
	if not SessionManager.active_timer.is_empty() \
			and SessionManager.active_timer.item_id == timer_current_item.item_id:
		if SessionManager.active_timer.paused:
			SessionManager.resume_timer()
			timer_is_running = true
			timer_play_button.text = "⏸"
		else:
			SessionManager.pause_timer()
			timer_is_running = false
			timer_play_button.text = "▶"
	else:
		var prev_sec := 0
		for r in SessionManager.sessions:
			if r.category_id == timer_current_item.category_id and r.custom_label == timer_current_item.custom_label:
				prev_sec += int(r.duration_min * 60.0)
		SessionManager.start_timer(timer_current_item, prev_sec)
		timer_is_running = true
		timer_play_button.text = "⏸"
	timer_stop_button.disabled = false


func _on_timer_stop_pressed() -> void:
	var record := SessionManager.stop_timer()
	_close_timer_view()
	refresh_list()
	GameManager.refresh_today_totals()

	# 운동 30분당 3코인 (시간에 비례해서 반올림 지급)
	var minutes := float(record.get("duration_min", 0.0))
	var reward := int(round(minutes * 3.0 / 30.0))
	if reward > 0:
		GameManager.award_coins(reward, "운동을 기록했어요!")


func _on_timer_back_pressed() -> void:
	# 시작 전에만 뒤로가기 허용 (진행 중에는 종료 버튼으로만 끝낼 수 있음)
	if not timer_is_running:
		_close_timer_view()


func _on_row_delete(item: Dictionary) -> void:
	for i in range(SessionManager.home_items.size()):
		if SessionManager.home_items[i].item_id == item.item_id:
			SessionManager.home_items.remove_at(i)
			break
	SessionManager.sessions = SessionManager.sessions.filter(func(rec):
		return not (rec.category_id == item.category_id and rec.custom_label == item.custom_label)
	)
	if not SessionManager.active_timer.is_empty() and SessionManager.active_timer.category_id == item.category_id and SessionManager.active_timer.custom_label == item.custom_label:
		SessionManager.active_timer = {}
	SessionManager.save_data()
	refresh_list()
	GameManager.refresh_today_totals()


func _on_row_edit(item: Dictionary) -> void:
	editing_item_id = item.item_id
	refresh_list()


func _on_row_save(item: Dictionary, edit_line: LineEdit) -> void:
	var new_text := edit_line.text.strip_edges()
	for i in range(SessionManager.home_items.size()):
		if SessionManager.home_items[i].item_id == item.item_id:
			SessionManager.home_items[i].custom_label = new_text
			SessionManager.save_data()
			break
	editing_item_id = ""
	refresh_list()


func _on_row_cancel() -> void:
	editing_item_id = ""
	refresh_list()


func _on_edit_toggle() -> void:
	edit_mode = not edit_mode
	side_actions.visible = false
	refresh_list()


func _on_item_selected_for_edit(item: Dictionary) -> void:
	selected_item = item
	side_actions.visible = true
	var cat := ExerciseData.get_category(item.category_id)
	if cat.is_custom:
		side_edit.visible = true
		side_edit.disabled = false
		side_edit_line.visible = false
		side_save.visible = false
		side_cancel.visible = false
	else:
		side_edit.visible = false
		side_edit_line.visible = false
		side_save.visible = false
		side_cancel.visible = false


func _on_side_delete() -> void:
	if selected_item == {}:
		return
	for i in range(SessionManager.home_items.size()):
		if SessionManager.home_items[i].item_id == selected_item.item_id:
			SessionManager.home_items.remove_at(i)
			break
	SessionManager.sessions = SessionManager.sessions.filter(func(rec):
		return not (rec.category_id == selected_item.category_id and rec.custom_label == selected_item.custom_label)
	)
	if not SessionManager.active_timer.is_empty() and SessionManager.active_timer.category_id == selected_item.category_id and SessionManager.active_timer.custom_label == selected_item.custom_label:
		SessionManager.active_timer = {}
	SessionManager.save_data()
	selected_item = {}
	side_actions.visible = false
	refresh_list()
	GameManager.refresh_today_totals()


func _on_side_edit() -> void:
	if selected_item == {}:
		return
	side_edit_line.visible = true
	side_save.visible = true
	side_cancel.visible = true
	side_edit_line.text = selected_item.custom_label


func _on_side_save() -> void:
	if selected_item == {}:
		return
	var new_text := side_edit_line.text.strip_edges()
	for i in range(SessionManager.home_items.size()):
		if SessionManager.home_items[i].item_id == selected_item.item_id:
			SessionManager.home_items[i].custom_label = new_text
			SessionManager.save_data()
			break
	selected_item = {}
	side_actions.visible = false
	side_edit_line.visible = false
	side_save.visible = false
	side_cancel.visible = false
	refresh_list()


func _on_side_cancel() -> void:
	side_edit_line.visible = false
	side_save.visible = false
	side_cancel.visible = false
