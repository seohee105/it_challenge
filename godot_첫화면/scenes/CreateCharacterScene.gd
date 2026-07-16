extends Control

@onready var nickname = $PanelContainer/MarginContainer/VBoxContainer/NicknameHBox/NicknameLineEdit
@onready var gender = $PanelContainer/MarginContainer/VBoxContainer/GenderHBox/GenderOptionButton
@onready var height = $PanelContainer/MarginContainer/VBoxContainer/HeightHBox/HeightSpinBox
@onready var weight = $PanelContainer/MarginContainer/VBoxContainer/WeightHBox/WeightSpinBox
@onready var age = $PanelContainer/MarginContainer/VBoxContainer/AgeHBox/AgeSpinBox


func _ready():
	gender.clear()

	gender.add_item("여성")
	gender.add_item("남성")

	gender.select(-1)


# ============================
# 버튼 Hover 효과
# ============================

func _on_start_button_mouse_entered() -> void:
	var tween = create_tween()
	tween.tween_property($StartButton, "scale", Vector2(1.08, 1.08), 0.12)


func _on_start_button_mouse_exited() -> void:
	var tween = create_tween()
	tween.tween_property($StartButton, "scale", Vector2(1.0, 1.0), 0.12)


# ============================
# START 버튼 클릭
# ============================

func _on_start_button_pressed() -> void:

	print("입력된 닉네임 =", nickname.text)
	print("글자 수 =", nickname.text.length())

	# 입력값 저장
	GameManager.update_player_info("nickname", nickname.text.strip_edges())
	GameManager.update_player_info("gender", gender.get_item_text(gender.selected))
	GameManager.update_player_info("height", height.value)
	GameManager.update_player_info("weight", weight.value)
	GameManager.update_player_info("age", age.value)

	# 오늘 날짜 저장
	GameManager.update_player_info(
		"last_login_date",
		Time.get_date_string_from_system()
	)

	# 파일 저장
	SaveManager.save_player(GameManager.player_data)

	print("저장 완료!")
	print("입력된 닉네임 =", nickname.text)
	print(GameManager.player_data)

	# HomeScene으로 이동
	get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")

func _on_start_button_focus_entered() -> void:
	pass # Replace with function body.
