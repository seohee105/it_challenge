extends RefCounted
class_name FoodRecordStore

## 분석 결과를 날짜별로 로컬에 저장한다. 달력 화면은 이 저장소를 그대로 읽어서 쓰면 된다.

const RECORDS_FILE := "user://food_records.json"
const PHOTOS_DIR := "user://food_photos"


func save_record(image_path: String, result: Dictionary) -> Dictionary:
	var now := Time.get_datetime_dict_from_system()
	var date_str := "%04d-%02d-%02d" % [now.year, now.month, now.day]
	var time_str := "%02d:%02d:%02d" % [now.hour, now.minute, now.second]

	var record := {
		"date": date_str,
		"time": time_str,
		"image_path": _copy_image_to_storage(image_path, date_str, time_str),
		"foods": result.get("foods", []),
		"game_delta": result.get("game_delta", {}),
	}

	var records := load_all_records()
	records.append(record)
	_write_records(records)
	return record


func load_all_records() -> Array:
	if not FileAccess.file_exists(RECORDS_FILE):
		return []
	var file := FileAccess.open(RECORDS_FILE, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		return []
	return parsed


func load_records_for_date(date_str: String) -> Array:
	var matches: Array = []
	for record in load_all_records():
		if typeof(record) == TYPE_DICTIONARY and record.get("date") == date_str:
			matches.append(record)
	return matches


func _write_records(records: Array) -> void:
	var file := FileAccess.open(RECORDS_FILE, FileAccess.WRITE)
	if file == null:
		push_error("음식 기록 파일을 저장할 수 없습니다: " + RECORDS_FILE)
		return
	file.store_string(JSON.stringify(records, "\t"))


func _copy_image_to_storage(source_path: String, date_str: String, time_str: String) -> String:
	if source_path.is_empty():
		return ""
	if not DirAccess.dir_exists_absolute(PHOTOS_DIR):
		DirAccess.make_dir_recursive_absolute(PHOTOS_DIR)

	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return ""
	var bytes := source.get_buffer(source.get_length())

	var ext := source_path.get_extension()
	if ext.is_empty():
		ext = "jpg"
	var file_name := "%s_%s.%s" % [date_str.replace("-", ""), time_str.replace(":", ""), ext]
	var dest_path := PHOTOS_DIR + "/" + file_name

	var dest := FileAccess.open(dest_path, FileAccess.WRITE)
	if dest == null:
		return ""
	dest.store_buffer(bytes)
	return dest_path
