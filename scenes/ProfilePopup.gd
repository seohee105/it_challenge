extends Control

signal edit_requested


@onready var nickname_label: Label = $NicknameLabel
@onready var gender_label: Label = $GenderLabel
@onready var height_label: Label = $HeightLabel
@onready var weight_label: Label = $WeightLabel
@onready var age_label: Label = $AgeLabel

@onready var edit_button: Button = $EditButton
@onready var close_button: Button = $CloseButton


func _ready() -> void:
	visible = false

	close_button.pressed.connect(
		_on_close_button_pressed
	)

	edit_button.pressed.connect(
		_on_edit_button_pressed
	)


# =========================================
# 프로필 표시
# =========================================

func show_profile() -> void:
	nickname_label.text = GameManager.player_data["nickname"]

	if GameManager.player_data["gender"] == "female":
		gender_label.text = "여"

	elif GameManager.player_data["gender"] == "male":
		gender_label.text = "남"

	else:
		gender_label.text = "-"


	height_label.text = "%.0f cm" % GameManager.player_data["height"]
	weight_label.text = "%.1f kg" % GameManager.player_data["weight"]
	age_label.text = "%d세" % GameManager.player_data["age"]

	visible = true


# =========================================
# 닫기
# =========================================

func _on_close_button_pressed() -> void:
	visible = false


# =========================================
# 수정하기
# =========================================

func _on_edit_button_pressed() -> void:
	print("수정하기 버튼 눌림!")

	# 현재 프로필 팝업 닫기
	visible = false

	# HomeScene에 수정 요청 보내기
	edit_requested.emit()
