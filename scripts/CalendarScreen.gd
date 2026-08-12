extends Control
class_name CalendarScreen

const WEEKDAY_LABELS := ["일", "월", "화", "수", "목", "금", "토"]
const DAYS_IN_MONTH := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

# 달력을 통째로 재사용하는 화면(예: 다이어리 임베드 페이지)마다 칸 크기를 다르게
# 키울 수 있도록 상수 대신 인스턴스별로 덮어쓸 수 있는 export 변수로 둔다.
@export var day_cell_size: Vector2 = Vector2(57, 84)
@export var weekday_header_size: Vector2 = Vector2(57, 26)
@export var day_number_font_size: int = 14

const TODAY_RING_COLOR := Color(0.82, 0.22, 0.22)
const SELECTED_RING_COLOR := Color(0.85, 0.62, 0.12)

const WEEKDAY_ICONS := [
	preload("res://assets/ui/weekday_sun.png"),
	preload("res://assets/ui/weekday_mon.png"),
	preload("res://assets/ui/weekday_tue.png"),
	preload("res://assets/ui/weekday_wed.png"),
	preload("res://assets/ui/weekday_thu.png"),
	preload("res://assets/ui/weekday_fri.png"),
	preload("res://assets/ui/weekday_sat.png"),
]
const TEX_DAY_CELL_TAN := preload("res://assets/ui/day_cell_tan.png")
const TEX_DAY_CELL_OTHER_MONTH := preload("res://assets/ui/day_cell_other_month.png")
const TEX_CLEAR_STAMP := preload("res://assets/ui/clear_stamp.png")

@onready var _month_label: Label = %MonthLabel
@onready var _day_grid: GridContainer = %DayGrid
@onready var _detail_date_label: Label = %DetailDateLabel
@onready var _photo_rect: TextureRect = %PhotoRect
@onready var _photo_index_label: Label = %PhotoIndexLabel
@onready var _total_kcal_label: Label = %TotalKcalLabel
@onready var _burned_kcal_label: Label = %BurnedKcalLabel
@onready var _net_kcal_label: Label = %NetKcalLabel
@onready var _carb_label: Label = %CarbLabel
@onready var _protein_label: Label = %ProteinLabel
@onready var _fat_label: Label = %FatLabel
@onready var _pie_chart: MacroPieChart = %PieChart
@onready var _weight_label: Label = %WeightLabel
@onready var _cardio_label: Label = %CardioLabel
@onready var _weekly_streak_label: Label = %WeeklyStreakLabel
@onready var _monthly_streak_label: Label = %MonthlyStreakLabel

var _record_store := FoodRecordStore.new()
var _view_year := 0
var _view_month := 0
var _today_date := ""
var _selected_date := ""
var _selected_day_records: Array = []
var _photo_index := 0
var _day_buttons: Dictionary = {}

var _tan_stylebox: StyleBoxTexture
var _today_ring_stylebox: StyleBoxFlat
var _selected_ring_stylebox: StyleBoxFlat


func _ready() -> void:
	_tan_stylebox = _make_stylebox(TEX_DAY_CELL_TAN)
	_today_ring_stylebox = _make_ring_stylebox(TODAY_RING_COLOR)
	_selected_ring_stylebox = _make_ring_stylebox(SELECTED_RING_COLOR)

	var today := Time.get_datetime_dict_from_system()
	_view_year = today.year
	_view_month = today.month
	_today_date = _format_date(today.year, today.month, today.day)
	_selected_date = _today_date

	%PrevMonthButton.pressed.connect(_on_prev_month)
	%NextMonthButton.pressed.connect(_on_next_month)
	%PrevPhotoButton.pressed.connect(_on_prev_photo)
	%NextPhotoButton.pressed.connect(_on_next_photo)

	_rebuild_calendar()


func _make_stylebox(tex: Texture2D) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = tex
	return box


func _make_ring_stylebox(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.set_border_width_all(3)
	box.border_color = color
	box.set_corner_radius_all(10)
	return box


func _make_ring(stylebox: StyleBoxFlat, ring_name: String) -> Panel:
	var ring := Panel.new()
	ring.name = ring_name
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.add_theme_stylebox_override("panel", stylebox)
	return ring


func _format_date(year: int, month: int, day: int) -> String:
	return "%04d-%02d-%02d" % [year, month, day]


func _on_prev_month() -> void:
	_view_month -= 1
	if _view_month < 1:
		_view_month = 12
		_view_year -= 1
	_rebuild_calendar()


func _on_next_month() -> void:
	_view_month += 1
	if _view_month > 12:
		_view_month = 1
		_view_year += 1
	_rebuild_calendar()


func _is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)


func _days_in_month(year: int, month: int) -> int:
	if month == 2 and _is_leap_year(year):
		return 29
	return DAYS_IN_MONTH[month - 1]


func _weekday_of(year: int, month: int, day: int) -> int:
	var unix := Time.get_unix_time_from_datetime_dict(
		{"year": year, "month": month, "day": day, "hour": 0, "minute": 0, "second": 0}
	)
	# Time.WEEKDAY_SUNDAY(0)~WEEKDAY_SATURDAY(6), WEEKDAY_LABELS와 순서가 같다.
	return Time.get_datetime_dict_from_unix_time(int(unix)).get("weekday", 0)


func _rebuild_calendar() -> void:
	_month_label.text = "%d년 %d월" % [_view_year, _view_month]

	for child in _day_grid.get_children():
		child.queue_free()
	_day_buttons.clear()

	# 요일 헤더와 날짜 칸을 같은 GridContainer에 넣어야 열 너비 계산이 하나로 맞아
	# 두 줄이 어긋나지 않는다 (헤더용 GridContainer를 따로 두면 각자 계산해 밀린다).
	for weekday_icon in WEEKDAY_ICONS:
		var header := TextureRect.new()
		header.texture = weekday_icon
		header.custom_minimum_size = weekday_header_size
		header.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		header.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_day_grid.add_child(header)

	var first_weekday := _weekday_of(_view_year, _view_month, 1)
	for _i in range(first_weekday):
		_day_grid.add_child(_make_filler_cell())

	var records_by_date := _group_records_by_date(_record_store.load_all_records())
	var total_days := _days_in_month(_view_year, _view_month)
	for day in range(1, total_days + 1):
		var date_str := _format_date(_view_year, _view_month, day)
		var cell := _make_day_cell(day, date_str, records_by_date.get(date_str, []))
		_day_grid.add_child(cell)
		_day_buttons[date_str] = cell

	var last_weekday := _weekday_of(_view_year, _view_month, total_days)
	for _i in range(6 - last_weekday):
		_day_grid.add_child(_make_filler_cell())

	if not _day_buttons.has(_selected_date):
		_selected_date = _format_date(_view_year, _view_month, 1)
	_select_date(_selected_date)


func _make_filler_cell() -> Control:
	var rect := TextureRect.new()
	rect.texture = TEX_DAY_CELL_OTHER_MONTH
	rect.custom_minimum_size = day_cell_size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	return rect


func _group_records_by_date(records: Array) -> Dictionary:
	var grouped := {}
	for record in records:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var date_str: String = record.get("date", "")
		if not grouped.has(date_str):
			grouped[date_str] = []
		grouped[date_str].append(record)
	return grouped


func _make_day_cell(day: int, date_str: String, day_records: Array) -> Button:
	var button := Button.new()
	button.custom_minimum_size = day_cell_size
	button.clip_text = true
	button.flat = true
	button.add_theme_stylebox_override("normal", _tan_stylebox)
	button.add_theme_stylebox_override("hover", _tan_stylebox)
	button.add_theme_stylebox_override("pressed", _tan_stylebox)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.clip_contents = true
	vbox.add_theme_constant_override("separation", 0)
	button.add_child(vbox)

	var day_label := Label.new()
	day_label.text = str(day)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.add_theme_font_size_override("font_size", day_number_font_size)
	vbox.add_child(day_label)

	if not day_records.is_empty():
		var last_record: Dictionary = day_records.back()
		var texture := _load_texture(last_record.get("image_path", ""))
		if texture != null:
			var texture_rect := TextureRect.new()
			texture_rect.custom_minimum_size = Vector2(34, 34)
			texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.texture = texture
			vbox.add_child(texture_rect)
	elif _is_day_cleared(date_str):
		var clear_rect := TextureRect.new()
		clear_rect.name = "ClearStamp"
		clear_rect.texture = TEX_CLEAR_STAMP
		clear_rect.custom_minimum_size = Vector2(48, 30)
		clear_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		clear_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vbox.add_child(clear_rect)

	if date_str == _today_date:
		button.add_child(_make_ring(_today_ring_stylebox, "TodayRing"))

	button.pressed.connect(_select_date.bind(date_str))
	return button


func _is_day_cleared(_date_str: String) -> bool:
	# TODO: 운동 스테이지 담당자의 클리어 결과가 연동되면 그 값을 반환하도록 교체.
	return false


func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _select_date(date_str: String) -> void:
	_selected_date = date_str
	_selected_day_records = _record_store.load_records_for_date(date_str)
	_photo_index = max(_selected_day_records.size() - 1, 0)
	_update_selection_highlight()
	_refresh_detail_panel()


func _update_selection_highlight() -> void:
	for date_str in _day_buttons.keys():
		var button: Button = _day_buttons[date_str]
		var existing_ring := button.get_node_or_null("SelectedRing")
		if existing_ring:
			button.remove_child(existing_ring)
			existing_ring.queue_free()
		if date_str == _selected_date:
			button.add_child(_make_ring(_selected_ring_stylebox, "SelectedRing"))


func _refresh_detail_panel() -> void:
	var parts := _selected_date.split("-")
	if parts.size() == 3:
		_detail_date_label.text = "%d월 %d일" % [int(parts[1]), int(parts[2])]
	else:
		_detail_date_label.text = _selected_date

	var total_kcal := 0.0
	var total_carb := 0.0
	var total_protein := 0.0
	var total_fat := 0.0
	for record in _selected_day_records:
		var game_delta: Dictionary = record.get("game_delta", {})
		var macros: Dictionary = game_delta.get("macros", {})
		total_kcal += float(game_delta.get("meal_kcal", 0.0))
		total_carb += float(macros.get("carb_g", 0.0))
		total_protein += float(macros.get("protein_g", 0.0))
		total_fat += float(macros.get("fat_g", 0.0))

	var exercise_stats := _get_exercise_stats(_selected_date)
	var burned_kcal: float = exercise_stats.total_cal
	var net_kcal := total_kcal - burned_kcal

	_total_kcal_label.text = "총 섭취 칼로리: %s kcal" % _format_number(total_kcal)
	_burned_kcal_label.text = "총 소모 칼로리: %s kcal" % _format_number(burned_kcal)
	_net_kcal_label.text = "최종 칼로리: %s kcal" % _format_number(net_kcal)
	_carb_label.text = "탄수화물: %s g" % _format_number(total_carb)
	_protein_label.text = "단백질: %s g" % _format_number(total_protein)
	_fat_label.text = "지방: %s g" % _format_number(total_fat)
	_pie_chart.set_macros(total_carb, total_protein, total_fat)

	_weight_label.text = "웨이트 %d분" % [int(round(exercise_stats.weight_min))]
	_cardio_label.text = "유산소 %d분" % [int(round(exercise_stats.cardio_min))]

	# 주간/월간 연속 달성 코인: 판정 기준(하루 클리어 정의)이 아직 없어 로직은 비워두고
	# 화면 자리만 만들어둔다.
	_weekly_streak_label.text = "주간 0/3"
	_monthly_streak_label.text = "월간 0/1"

	_update_photo_view()


func _get_exercise_stats(date_str: String) -> Dictionary:
	var total_cal := 0.0
	var weight_min := 0.0
	var cardio_min := 0.0
	for record in SessionManager.sessions:
		if typeof(record) != TYPE_DICTIONARY or record.get("date", "") != date_str:
			continue
		var cal := float(record.get("calories", 0.0))
		total_cal += cal
		var duration_min := float(record.get("duration_min", 0.0))
		if ExerciseData.get_icon(record.get("category_id", "")) == ExerciseData.ICON_CARDIO:
			cardio_min += duration_min
		else:
			weight_min += duration_min
	return {"total_cal": total_cal, "weight_min": weight_min, "cardio_min": cardio_min}


func _update_photo_view() -> void:
	if _selected_day_records.is_empty():
		_photo_rect.texture = null
		_photo_index_label.text = "기록된 사진이 없습니다"
		return

	_photo_index = clamp(_photo_index, 0, _selected_day_records.size() - 1)
	var record: Dictionary = _selected_day_records[_photo_index]
	_photo_rect.texture = _load_texture(record.get("image_path", ""))
	_photo_index_label.text = "%d / %d" % [_photo_index + 1, _selected_day_records.size()]


func _on_prev_photo() -> void:
	if _selected_day_records.is_empty():
		return
	_photo_index = (_photo_index - 1 + _selected_day_records.size()) % _selected_day_records.size()
	_update_photo_view()


func _on_next_photo() -> void:
	if _selected_day_records.is_empty():
		return
	_photo_index = (_photo_index + 1) % _selected_day_records.size()
	_update_photo_view()


func _format_number(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return str(snapped(value, 0.1))
