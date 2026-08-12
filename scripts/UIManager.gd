extends Node
class_name UIManager

@export var image_rect_path: NodePath
@export var status_label_path: NodePath
@export var result_label_path: NodePath
@export var analyze_button_path: NodePath

# 다이어리 오른쪽 페이지에 사진 + 칼로리/탄단지 요약을 따로 보여주기 위한
# 선택적 노드들. 비워두면(예: control.tscn) 그냥 무시된다.
@export var result_photo_rect_path: NodePath
@export var result_kcal_label_path: NodePath
@export var result_carb_label_path: NodePath
@export var result_protein_label_path: NodePath
@export var result_fat_label_path: NodePath

var _image_rect: TextureRect
var _status_label: Label
var _result_label: Label
var _analyze_button: Button

var _result_photo_rect: TextureRect
var _result_kcal_label: Label
var _result_carb_label: Label
var _result_protein_label: Label
var _result_fat_label: Label


func _ready() -> void:
	_image_rect = get_node(image_rect_path)
	_status_label = get_node(status_label_path)
	_result_label = get_node(result_label_path)
	_analyze_button = get_node(analyze_button_path)

	_result_photo_rect = _get_optional_node(result_photo_rect_path)
	_result_kcal_label = _get_optional_node(result_kcal_label_path)
	_result_carb_label = _get_optional_node(result_carb_label_path)
	_result_protein_label = _get_optional_node(result_protein_label_path)
	_result_fat_label = _get_optional_node(result_fat_label_path)

	show_idle()


func _get_optional_node(path: NodePath) -> Node:
	if path.is_empty():
		return null
	return get_node_or_null(path)


func show_idle() -> void:
	set_busy(false)
	set_status("📸 사진을 촬영하거나 갤러리에서 선택해주세요.")
	_result_label.text = ""
	_clear_result_summary()


func set_busy(is_busy: bool) -> void:
	if _analyze_button != null:
		_analyze_button.disabled = is_busy


func set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message


func show_selected_image(image_path: String) -> bool:
	var image := Image.new()
	var err := image.load(image_path)
	if err != OK:
		show_error("사진 미리보기를 표시할 수 없습니다.")
		return false

	_image_rect.texture = ImageTexture.create_from_image(image)
	set_status("✅ 사진이 준비되었습니다. Analyze 버튼을 눌러주세요.")
	_result_label.text = ""
	_clear_result_summary()
	return true


func show_analyzing() -> void:
	set_busy(true)
	set_status("🔍 AI가 사진을 분석하고 있습니다...")
	_result_label.text = ""


func show_error(message: String) -> void:
	set_busy(false)
	set_status(message)


func show_result(result: Dictionary) -> void:
	set_busy(false)
	var foods: Array = result.get("foods", [])
	if foods.is_empty():
		set_status("😥 음식을 찾지 못했습니다. 음식이 잘 보이는 사진으로 다시 시도해주세요.")
		_result_label.text = ""
		_clear_result_summary()
		return

	set_status("🎉 AI 분석이 완료되었습니다.")
	var lines: Array[String] = []
	for index in foods.size():
		var food: Dictionary = foods[index]
		if foods.size() > 1:
			lines.append("[음식 " + str(index + 1) + "]")
		lines.append("음식명: " + str(food.get("name", "알 수 없음")))
		lines.append("신뢰도: " + _format_percent(food.get("confidence", 0.0)))
		lines.append("칼로리: " + _format_number(food.get("calorie", 0)) + " kcal")
		lines.append("탄수화물: " + _format_number(food.get("carb", 0)) + " g")
		lines.append("단백질: " + _format_number(food.get("protein", 0)) + " g")
		lines.append("지방: " + _format_number(food.get("fat", 0)) + " g")
		lines.append("나트륨: " + _format_number(food.get("sodium", 0)) + " mg")
		lines.append("")

	var game_delta: Dictionary = result.get("game_delta", {})
	var macros: Dictionary = {}
	if not game_delta.is_empty():
		macros = game_delta.get("macros", {})
		lines.append("[게임 적용 데이터]")
		lines.append("식사 칼로리: " + _format_number(game_delta.get("meal_kcal", 0)) + " kcal")
		lines.append("음식 개수: " + str(game_delta.get("food_count", foods.size())))
		lines.append("탄수화물 합계: " + _format_number(macros.get("carb_g", 0)) + " g")
		lines.append("단백질 합계: " + _format_number(macros.get("protein_g", 0)) + " g")
		lines.append("지방 합계: " + _format_number(macros.get("fat_g", 0)) + " g")
		lines.append("나트륨 합계: " + _format_number(macros.get("sodium_mg", 0)) + " mg")

	_result_label.text = "\n".join(lines)
	_update_result_summary(game_delta, macros)


func _update_result_summary(game_delta: Dictionary, macros: Dictionary) -> void:
	if _result_photo_rect:
		_result_photo_rect.texture = _image_rect.texture

	if _result_kcal_label:
		_result_kcal_label.text = "🔥 칼로리: " + _format_number(game_delta.get("meal_kcal", 0)) + " kcal"
	if _result_carb_label:
		_result_carb_label.text = "🍚 탄수화물: " + _format_number(macros.get("carb_g", 0)) + " g"
	if _result_protein_label:
		_result_protein_label.text = "🍗 단백질: " + _format_number(macros.get("protein_g", 0)) + " g"
	if _result_fat_label:
		_result_fat_label.text = "🥑 지방: " + _format_number(macros.get("fat_g", 0)) + " g"


func _clear_result_summary() -> void:
	if _result_photo_rect:
		_result_photo_rect.texture = null
	if _result_kcal_label:
		_result_kcal_label.text = "🔥 칼로리: -"
	if _result_carb_label:
		_result_carb_label.text = "🍚 탄수화물: -"
	if _result_protein_label:
		_result_protein_label.text = "🍗 단백질: -"
	if _result_fat_label:
		_result_fat_label.text = "🥑 지방: -"


func _format_number(value: Variant) -> String:
	var number := float(value)
	if is_equal_approx(number, round(number)):
		return str(int(round(number)))
	return str(snapped(number, 0.1))


func _format_percent(value: Variant) -> String:
	var confidence := clampf(float(value), 0.0, 1.0)
	return str(int(round(confidence * 100.0))) + "%"
