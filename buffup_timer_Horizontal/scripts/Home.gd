extends Control

@onready var item_container: VBoxContainer = $VBox/ScrollContainer/ItemContainer
@onready var add_button: Button = $VBox/BottomBar/AddButton
@onready var edit_toggle_button: Button = $VBox/BottomBar/EditDeleteButton
@onready var today_cal_label: Label = $VBox/BottomBar/TodayCalLabel
@onready var side_actions: Panel = $SideActions
@onready var side_delete: Button = $SideActions/VBox/DeleteButton
@onready var side_edit: Button = $SideActions/VBox/EditButton
@onready var side_edit_line: LineEdit = $SideActions/VBox/EditLine
@onready var side_save: Button = $SideActions/VBox/SaveEditButton
@onready var side_cancel: Button = $SideActions/VBox/CancelEditButton

var edit_mode: bool = false
var selected_item: Dictionary = {}
var editing_item_id: String = ""


func _ready() -> void:
	add_button.pressed.connect(_on_add_pressed)
	edit_toggle_button.pressed.connect(_on_edit_toggle)
	side_delete.pressed.connect(_on_side_delete)
	side_edit.pressed.connect(_on_side_edit)
	side_save.pressed.connect(_on_side_save)
	side_cancel.pressed.connect(_on_side_cancel)
	refresh_list()

	# 앱을 종료했다가 다시 켰는데 진행 중이던 타이머가 있으면 바로 이어서 볼 수 있게 함
	if not SessionManager.active_timer.is_empty():
		SessionManager.pending_item = {
			"item_id": SessionManager.active_timer.item_id,
			"category_id": SessionManager.active_timer.category_id,
			"custom_label": SessionManager.active_timer.custom_label,
		}
		get_tree().change_scene_to_file("res://scenes/ExerciseTimer.tscn")


func _on_add_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/AddExercise.tscn")


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
		var stats := _get_item_stats(item)
		today_total += stats.total_cal

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0, 72)
		row.add_theme_constant_override("separation", 12)

		var btn := Button.new()
		btn.text = label_text
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 72)

		if edit_mode:
			btn.pressed.connect(_on_item_selected_for_edit.bind(item))
		else:
			btn.pressed.connect(_on_item_pressed.bind(item))

		row.add_child(btn)

		var right_v := VBoxContainer.new()
		right_v.size_flags_horizontal = Control.SIZE_SHRINK_END
		right_v.custom_minimum_size = Vector2(220, 0)
		right_v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		right_v.add_theme_constant_override("separation", 4)

		var time_label := Label.new()
		time_label.text = _format_seconds(stats.total_sec)
		var cal_label := Label.new()
		cal_label.text = "%.1f kcal" % [stats.total_cal]
		right_v.add_child(time_label)
		right_v.add_child(cal_label)

		if edit_mode:
			var actions := HBoxContainer.new()
			actions.size_flags_horizontal = Control.SIZE_SHRINK_END
			actions.add_theme_constant_override("separation", 6)

			var delete_button := Button.new()
			delete_button.text = "삭제"
			delete_button.pressed.connect(_on_row_delete.bind(item))
			actions.add_child(delete_button)

			if cat.is_custom:
				var edit_button := Button.new()
				edit_button.text = "수정"
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
				save_button.text = "저장"
				save_button.pressed.connect(_on_row_save.bind(item, edit_line))
				edit_actions.add_child(save_button)

				var cancel_button := Button.new()
				cancel_button.text = "취소"
				cancel_button.pressed.connect(_on_row_cancel)
				edit_actions.add_child(cancel_button)

				right_v.add_child(edit_actions)
			
		row.add_child(right_v)
		item_container.add_child(row)

	today_cal_label.text = "오늘의 총 소모 칼로리량: %.1f kcal" % [today_total]


func _get_item_stats(item: Dictionary) -> Dictionary:
	var total_sec := 0
	var total_cal := 0.0
	for r in SessionManager.sessions:
		if r.category_id == item.category_id and r.custom_label == item.custom_label:
			total_sec += int(r.duration_min * 60.0)
			total_cal += float(r.calories)
	return {"total_sec": total_sec, "total_cal": total_cal}


func _on_item_pressed(item: Dictionary) -> void:
	SessionManager.pending_item = item
	get_tree().change_scene_to_file("res://scenes/ExerciseTimer.tscn")


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
	# 기본 카테고리면 수정 불가 -> 삭제 버튼만 보이게
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
