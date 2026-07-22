extends Control

@onready var name_label: Label = $VBox/NameLabel
@onready var time_label: Label = $VBox/TimeLabel
@onready var play_button: Button = $VBox/ControlButtons/PlayButton
@onready var stop_button: Button = $VBox/ControlButtons/StopButton
@onready var back_button: Button = $VBox/BackButton

var current_item: Dictionary
var is_running: bool = false
var is_paused: bool = false


func _ready() -> void:
	current_item = SessionManager.pending_item
	var cat: Dictionary = ExerciseData.get_category(current_item.category_id)
	name_label.text = current_item.custom_label if current_item.custom_label != "" else cat.name

	play_button.pressed.connect(_on_play_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	back_button.pressed.connect(_on_back_pressed)
	play_button.text = "▶"
	stop_button.disabled = true

	if not SessionManager.active_timer.is_empty() \
			and SessionManager.active_timer.item_id == current_item.item_id:
		if SessionManager.active_timer.paused:
			is_paused = true
			is_running = false
			play_button.text = "▶"
		else:
			is_running = true
			is_paused = false
			play_button.text = "⏸"
		stop_button.disabled = false
		_update_time_label()
	else:
		var total_sec := 0
		for r in SessionManager.sessions:
			if r.category_id == current_item.category_id and r.custom_label == current_item.custom_label:
				total_sec += int(r.duration_min * 60.0)
		time_label.text = _format_seconds(total_sec)


func _process(_delta: float) -> void:
	if is_running:
		_update_time_label()


func _update_time_label() -> void:
	var elapsed := SessionManager.get_elapsed_seconds()
	var h := elapsed / 3600
	var m := (elapsed % 3600) / 60
	var s := elapsed % 60
	time_label.text = "%d:%02d:%02d" % [h, m, s]


func _format_seconds(sec: int) -> String:
	var h := sec / 3600
	var m := (sec % 3600) / 60
	var s := sec % 60
	return "%d:%02d:%02d" % [h, m, s]


func _on_play_pressed() -> void:
	if not SessionManager.active_timer.is_empty() \
			and SessionManager.active_timer.item_id == current_item.item_id:
		if SessionManager.active_timer.paused:
			SessionManager.resume_timer()
			is_running = true
			is_paused = false
			play_button.text = "⏸"
		else:
			SessionManager.pause_timer()
			is_running = false
			is_paused = true
			play_button.text = "▶"
	else:
		var prev_sec := 0
		for r in SessionManager.sessions:
			if r.category_id == current_item.category_id and r.custom_label == current_item.custom_label:
				prev_sec += int(r.duration_min * 60.0)
		SessionManager.start_timer(current_item, prev_sec)
		is_running = true
		is_paused = false
		play_button.text = "⏸"
	stop_button.disabled = false


func _on_stop_pressed() -> void:
	SessionManager.stop_timer()
	get_tree().change_scene_to_file("res://scenes/Home.tscn")


func _on_back_pressed() -> void:
	# 시작 전에만 뒤로가기 허용
	if not is_running:
		get_tree().change_scene_to_file("res://scenes/Home.tscn")
