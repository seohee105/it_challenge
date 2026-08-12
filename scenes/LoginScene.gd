extends Control

signal profile_saved(
	gender: String,
	height: float,
	weight: float,
	age: int
)

# =========================================
# 노드
# =========================================

@onready var male_button: TextureButton = $TextureRect/MaleButton
@onready var female_button: TextureButton = $TextureRect/FemaleButton

@onready var height_input: LineEdit = $TextureRect/HeightInput
@onready var weight_input: LineEdit = $TextureRect/WeightInput
@onready var age_input: LineEdit = $TextureRect/AgeInput

@onready var warning_label: Label = $TextureRect/WarningLabel

@onready var save_button: TextureButton = $TextureRect/SaveButton


# =========================================
# 선택된 성별
# =========================================

var selected_gender: String = ""


# =========================================
# 시작
# =========================================

func _ready() -> void:
	# StartScene에서 필요할 때만 표시
	visible = false

	warning_label.visible = false

	# =========================================
	# 성별 버튼 설정
	# =========================================

	# TextureButton을 선택 상태 유지 버튼으로 사용
	male_button.toggle_mode = true
	female_button.toggle_mode = true

	male_button.button_pressed = false
	female_button.button_pressed = false

	# 버튼 연결
	male_button.pressed.connect(_on_male_button_pressed)
	female_button.pressed.connect(_on_female_button_pressed)

	save_button.pressed.connect(_on_save_button_pressed)


	# =========================================
	# 입력창 포커스 연결
	# =========================================

	height_input.focus_entered.connect(_on_height_focus_entered)
	height_input.focus_exited.connect(_on_height_focus_exited)

	weight_input.focus_entered.connect(_on_weight_focus_entered)
	weight_input.focus_exited.connect(_on_weight_focus_exited)

	age_input.focus_entered.connect(_on_age_focus_entered)
	age_input.focus_exited.connect(_on_age_focus_exited)


# =========================================
# 남자 선택
# =========================================

func _on_male_button_pressed() -> void:
	selected_gender = "male"

	# 남자 버튼 선택 상태 유지
	male_button.set_pressed_no_signal(true)

	# 여자 버튼 선택 해제
	female_button.set_pressed_no_signal(false)

	print("남자 선택")


# =========================================
# 여자 선택
# =========================================

func _on_female_button_pressed() -> void:
	selected_gender = "female"

	# 여자 버튼 선택 상태 유지
	female_button.set_pressed_no_signal(true)

	# 남자 버튼 선택 해제
	male_button.set_pressed_no_signal(false)

	print("여자 선택")


# =========================================
# 키 입력창
# =========================================

func _on_height_focus_entered() -> void:
	height_input.placeholder_text = ""


func _on_height_focus_exited() -> void:
	if height_input.text.strip_edges() == "":
		height_input.placeholder_text = "키를 입력해주세요"


# =========================================
# 몸무게 입력창
# =========================================

func _on_weight_focus_entered() -> void:
	weight_input.placeholder_text = ""


func _on_weight_focus_exited() -> void:
	if weight_input.text.strip_edges() == "":
		weight_input.placeholder_text = "몸무게를 입력해주세요"


# =========================================
# 나이 입력창
# =========================================

func _on_age_focus_entered() -> void:
	age_input.placeholder_text = ""


func _on_age_focus_exited() -> void:
	if age_input.text.strip_edges() == "":
		age_input.placeholder_text = "나이를 입력해주세요"


# =========================================
# 저장 버튼
# =========================================

func _on_save_button_pressed() -> void:
	warning_label.visible = false


	# =========================================
	# 성별 확인
	# =========================================

	if selected_gender == "":
		show_warning("성별을 선택해주세요.")
		return


	# =========================================
	# 키 확인
	# =========================================

	if height_input.text.strip_edges() == "":
		show_warning("키를 입력해주세요.")
		return


	# =========================================
	# 몸무게 확인
	# =========================================

	if weight_input.text.strip_edges() == "":
		show_warning("몸무게를 입력해주세요.")
		return


	# =========================================
	# 나이 확인
	# =========================================

	if age_input.text.strip_edges() == "":
		show_warning("나이를 입력해주세요.")
		return


	# =========================================
	# 숫자인지 확인
	# =========================================

	if not height_input.text.is_valid_float():
		show_warning("키를 숫자로 입력해주세요.")
		return

	if not weight_input.text.is_valid_float():
		show_warning("몸무게를 숫자로 입력해주세요.")
		return

	if not age_input.text.is_valid_int():
		show_warning("나이를 숫자로 입력해주세요.")
		return


	# =========================================
	# 입력값 가져오기
	# =========================================

	var height: float = height_input.text.to_float()
	var weight: float = weight_input.text.to_float()
	var age: int = age_input.text.to_int()


	# =========================================
	# 테스트 출력
	# =========================================

	print("========================")
	print("기본 정보 입력 완료!")
	print("성별: ", selected_gender)
	print("키: ", height)
	print("몸무게: ", weight)
	print("나이: ", age)
	print("========================")


	# =========================================
	# StartScene에 완료 신호 보내기
	# =========================================

	profile_saved.emit(
		selected_gender,
		height,
		weight,
		age
	)

	# LoginScene 닫기
	visible = false


# =========================================
# 경고 메시지
# =========================================

func show_warning(message: String) -> void:
	warning_label.text = "! " + message + " !"
	warning_label.visible = true
