extends Node
## 홈 화면 항목, 진행 중인 타이머, 완료된 세션 기록을 관리하고
## user:// 에 JSON으로 저장한다.
## 타이머는 시작 시각(unix time)을 저장해두고 경과시간을 그때그때
## "현재시각 - 시작시각"으로 재계산하므로, 앱이 백그라운드로 가거나
## 다시 열려도(심지어 OS가 프로세스를 종료했다가 재실행해도) 정확하다.

signal session_saved(record: Dictionary)

const SAVE_PATH := "user://buffup_data.json"

var user_weight_kg: float = 70.0
var home_items: Array = []      # [{item_id, category_id, custom_label}]
var sessions: Array = []        # 완료된 운동 기록
var active_timer: Dictionary = {}   # 현재 카운트 중인 타이머
var pending_item: Dictionary = {}   # 타이머 화면에 진입했지만 아직 시작 안 누른 항목
var last_saved_date: String = ""
var daily_history: Array = []


func _ready() -> void:
	load_data()


## ---- 홈 화면 항목 추가 (열품타의 "과목 추가"에 해당) ----
func add_home_item(category_id: String, custom_label: String = "") -> Dictionary:
	var item := {
		"item_id": str(Time.get_unix_time_from_system()) + "_" + category_id,
		"category_id": category_id,
		"custom_label": custom_label,
	}
	home_items.append(item)
	save_data()
	return item


## ---- 타이머 시작 ----
func start_timer(item: Dictionary, offset_seconds: int = 0) -> void:
	var cat := ExerciseData.get_category(item.category_id)
	active_timer = {
		"item_id": item.item_id,
		"category_id": item.category_id,
		"custom_label": item.custom_label,
		"met": cat.met,
		"start_unix": Time.get_unix_time_from_system(),
		"offset_seconds": offset_seconds,
		"paused": false,
		"elapsed_before_pause": 0,
		"pause_unix": 0,
	}
	save_data()


func resume_timer() -> void:
	if active_timer.is_empty() or not active_timer.paused:
		return
	active_timer["offset_seconds"] = int(active_timer.get("offset_seconds", 0)) + int(active_timer.elapsed_before_pause)
	active_timer["elapsed_before_pause"] = 0
	active_timer["start_unix"] = Time.get_unix_time_from_system()
	active_timer["paused"] = false
	active_timer["pause_unix"] = 0
	save_data()


func pause_timer() -> void:
	if active_timer.is_empty() or active_timer.paused:
		return
	active_timer["elapsed_before_pause"] = int(Time.get_unix_time_from_system() - active_timer.start_unix)
	active_timer["paused"] = true
	active_timer["pause_unix"] = Time.get_unix_time_from_system()
	save_data()


## ---- 경과 시간(초) 조회 ----
func get_elapsed_seconds() -> int:
	if active_timer.is_empty():
		return 0
	var base := int(active_timer.get("offset_seconds", 0))
	if active_timer.paused:
		return base + int(active_timer.get("elapsed_before_pause", 0))
	return base + int(Time.get_unix_time_from_system() - active_timer.start_unix)


## ---- 종료: 즉시 계산 + 저장 후 홈으로 ----
func stop_timer() -> Dictionary:
	if active_timer.is_empty():
		return {}

	var elapsed_sec := get_elapsed_seconds()
	var duration_hour := elapsed_sec / 3600.0
	var calories = active_timer.met * user_weight_kg * duration_hour
	var duration_min := elapsed_sec / 60.0

	var record := {
		"category_id": active_timer.category_id,
		"custom_label": active_timer.custom_label,
		"met": active_timer.met,
		"start_unix": active_timer.start_unix,
		"end_unix": Time.get_unix_time_from_system(),
		"duration_min": duration_min,
		"duration_sec": elapsed_sec,
		"weight_kg": user_weight_kg,
		"calories": calories,
		"date": Time.get_date_string_from_unix_time(active_timer.start_unix),
	}

	sessions.append(record)
	active_timer = {}
	save_data()
	session_saved.emit(record)
	return record


## ---- 저장 / 로드 ----
func save_data() -> void:
	_apply_daily_rollover()
	last_saved_date = _current_date_string()
	var data := {
		"user_weight_kg": user_weight_kg,
		"home_items": home_items,
		"active_timer": active_timer,
		"sessions": sessions,
		"last_saved_date": last_saved_date,
		"daily_history": daily_history,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var text := f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		user_weight_kg = parsed.get("user_weight_kg", user_weight_kg)
		home_items = parsed.get("home_items", [])
		active_timer = parsed.get("active_timer", {})
		sessions = parsed.get("sessions", [])
		last_saved_date = parsed.get("last_saved_date", last_saved_date)
		daily_history = parsed.get("daily_history", daily_history)
		_apply_daily_rollover()


func _current_date_string() -> String:
	return Time.get_date_string_from_unix_time(Time.get_unix_time_from_system())


func _archive_day(date_str: String) -> void:
	var total_cal := 0.0
	var total_duration := 0.0
	for rec in sessions:
		total_cal += float(rec.get("calories", 0.0))
		total_duration += float(rec.get("duration_min", 0.0))
	daily_history.append({
		"date": date_str,
		"total_calories": total_cal,
		"total_duration_min": total_duration,
		"sessions": sessions.duplicate(),
	})


func _apply_daily_rollover() -> void:
	var today := _current_date_string()
	if last_saved_date == "":
		last_saved_date = today
		return
	if last_saved_date != today:
		if sessions.size() > 0:
			_archive_day(last_saved_date)
		sessions = []
		active_timer = {}
		last_saved_date = today
