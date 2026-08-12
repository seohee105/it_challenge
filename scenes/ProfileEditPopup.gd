extends Control

signal profile_updated


@onready var nickname_input: LineEdit = $NicknameInput

@onready var male_button: TextureButton = $MaleButton
@onready var female_button: TextureButton = $FemaleButton

@onready var height_input: LineEdit = $HeightInput
@onready var weight_input: LineEdit = $WeightInput
@onready var age_input: LineEdit = $AgeInput

@onready var warning_label: Label = $WarningLabel

@onready var save_button: Button = $SaveButton
@onready var cancel_button: Button = $CancelButton


var selected_gender: String = ""

var nickname_tween: Tween
var height_tween: Tween
var weight_tween: Tween
var age_tween: Tween

var placeholder_color := Color(0.55, 0.55, 0.55, 1.0)


func _ready() -> void:
	visible = false

	warning_label.visible = false

	male_button.toggle_mode = true
	female_button.toggle_mode = true


	# =========================================
	# 버튼 연결
	# =========================================

	male_button.pressed.connect(
		_on_male_button_pressed
	)

	female_button.pressed.connect(
		_on_female_button_pressed
	)

	save_button.pressed.connect(
		_on_save_button_pressed
	)

	cancel_button.pressed.connect(
		_on_cancel_button_pressed
	)


	# =========================================
	# 마우스 올렸을 때 Placeholder 숨김
	# =========================================

	nickname_input.mouse_entered.connect(
		_on_nickname_mouse_entered
	)

	nickname_input.mouse_exited.connect(
		_on_nickname_mouse_exited
	)

	height_input.mouse_entered.connect(
		_on_height_mouse_entered
	)

	height_input.mouse_exited.connect(
		_on_height_mouse_exited
	)

	weight_input.mouse_entered.connect(
		_on_weight_mouse_entered
	)

	weight_input.mouse_exited.connect(
		_on_weight_mouse_exited
	)

	age_input.mouse_entered.connect(
		_on_age_mouse_entered
	)

	age_input.mouse_exited.connect(
		_on_age_mouse_exited
	)


# =========================================
# 수정창 열기
# =========================================

func open_edit() -> void:
	warning_label.visible = false

	# 기존 저장값이 있으면 입력창에 표시
	nickname_input.text = GameManager.player_data["nickname"]

	height_input.text = "%.0f" % GameManager.player_data["height"]
	weight_input.text = "%.1f" % GameManager.player_data["weight"]
	age_input.text = "%d" % GameManager.player_data["age"]

	selected_gender = GameManager.player_data["gender"]


	# =========================================
	# 성별 버튼 상태
	# =========================================

	if selected_gender == "male":
		male_button.set_pressed_no_signal(true)
		female_button.set_pressed_no_signal(false)

	elif selected_gender == "female":
		male_button.set_pressed_no_signal(false)
		female_button.set_pressed_no_signal(true)

	else:
		male_button.set_pressed_no_signal(false)
		female_button.set_pressed_no_signal(false)


	visible = true


# =========================================
# Placeholder 깜빡임 공통 함수
# =========================================

func start_placeholder_blink(
	input: LineEdit,
	type: String
) -> void:

	var bright := placeholder_color
	bright.a = 1.0

	var faded := placeholder_color
	faded.a = 0.25


	match type:

		"nickname":
			if nickname_tween != null:
				nickname_tween.kill()

			nickname_tween = create_tween()
			nickname_tween.set_loops()

			nickname_tween.tween_method(
				func(color: Color):
					input.add_theme_color_override(
						"font_placeholder_color",
						color
					),
				bright,
				faded,
				0.65
			)

			nickname_tween.tween_method(
				func(color: Color):
					input.add_theme_color_override(
						"font_placeholder_color",
						color
					),
				faded,
				bright,
				0.65
			)


		"height":
			if height_tween != null:
				height_tween.kill()

			height_tween = create_tween()
			height_tween.set_loops()

			height_tween.tween_method(
				func(color: Color):
					input.add_theme_color_override(
						"font_placeholder_color",
						color
					),
				bright,
				faded,
				0.65
			)

			height_tween.tween_method(
				func(color: Color):
					input.add_theme_color_override(
						"font_placeholder_color",
						color
					),
				faded,
				bright,
				0.65
			)


		"weight":
			if weight_tween != null:
				weight_tween.kill()

			weight_tween = create_tween()
			weight_tween.set_loops()

			weight_tween.tween_method(
				func(color: Color):
					input.add_theme_color_override(
						"font_placeholder_color",
						color
					),
				bright,
				faded,
				0.65
			)

			weight_tween.tween_method(
				func(color: Color):
					input.add_theme_color_override(
						"font_placeholder_color",
						color
					),
				faded,
				bright,
				0.65
			)


		"age":
			if age_tween != null:
				age_tween.kill()

			age_tween = create_tween()
			age_tween.set_loops()

			age_tween.tween_method(
				func(color: Color):
					input.add_theme_color_override(
						"font_placeholder_color",
						color
					),
				bright,
				faded,
				0.65
			)

			age_tween.tween_method(
				func(color: Color):
					input.add_theme_color_override(
						"font_placeholder_color",
						color
					),
				faded,
				bright,
				0.65
			)


# =========================================
# 닉네임
# =========================================

func _on_nickname_mouse_entered() -> void:
	if nickname_input.text.strip_edges() == "":
		nickname_input.placeholder_text = ""

	if nickname_tween != null:
		nickname_tween.kill()


func _on_nickname_mouse_exited() -> void:
	if nickname_input.text.strip_edges() == "":
		nickname_input.placeholder_text = "닉네임을 입력하세요"
		start_placeholder_blink(
			nickname_input,
			"nickname"
		)


# =========================================
# 키
# =========================================

func _on_height_mouse_entered() -> void:
	if height_input.text.strip_edges() == "":
		height_input.placeholder_text = ""

	if height_tween != null:
		height_tween.kill()


func _on_height_mouse_exited() -> void:
	if height_input.text.strip_edges() == "":
		height_input.placeholder_text = "키를 입력하세요"
		start_placeholder_blink(
			height_input,
			"height"
		)


# =========================================
# 몸무게
# =========================================

func _on_weight_mouse_entered() -> void:
	if weight_input.text.strip_edges() == "":
		weight_input.placeholder_text = ""

	if weight_tween != null:
		weight_tween.kill()


func _on_weight_mouse_exited() -> void:
	if weight_input.text.strip_edges() == "":
		weight_input.placeholder_text = "몸무게를 입력하세요"
		start_placeholder_blink(
			weight_input,
			"weight"
		)


# =========================================
# 나이
# =========================================

func _on_age_mouse_entered() -> void:
	if age_input.text.strip_edges() == "":
		age_input.placeholder_text = ""

	if age_tween != null:
		age_tween.kill()


func _on_age_mouse_exited() -> void:
	if age_input.text.strip_edges() == "":
		age_input.placeholder_text = "나이를 입력하세요"
		start_placeholder_blink(
			age_input,
			"age"
		)


# =========================================
# 남자 선택
# =========================================

func _on_male_button_pressed() -> void:
	selected_gender = "male"

	male_button.set_pressed_no_signal(true)
	female_button.set_pressed_no_signal(false)


# =========================================
# 여자 선택
# =========================================

func _on_female_button_pressed() -> void:
	selected_gender = "female"

	female_button.set_pressed_no_signal(true)
	male_button.set_pressed_no_signal(false)


# =========================================
# 저장
# =========================================

func _on_save_button_pressed() -> void:
	warning_label.visible = false

	var nickname := nickname_input.text.strip_edges()


	if nickname == "":
		show_warning("닉네임을 입력해주세요.")
		return

	if nickname.length() > 10:
		show_warning("닉네임은 10자 이하로 입력해주세요.")
		return


	if selected_gender == "":
		show_warning("성별을 선택해주세요.")
		return


	if height_input.text.strip_edges() == "":
		show_warning("키를 입력해주세요.")
		return

	if not height_input.text.is_valid_float():
		show_warning("키를 숫자로 입력해주세요.")
		return


	if weight_input.text.strip_edges() == "":
		show_warning("몸무게를 입력해주세요.")
		return

	if not weight_input.text.is_valid_float():
		show_warning("몸무게를 숫자로 입력해주세요.")
		return


	if age_input.text.strip_edges() == "":
		show_warning("나이를 입력해주세요.")
		return

	if not age_input.text.is_valid_int():
		show_warning("나이를 숫자로 입력해주세요.")
		return


	var height := height_input.text.to_float()
	var weight := weight_input.text.to_float()
	var age := age_input.text.to_int()


	GameManager.update_player_info("nickname", nickname)
	GameManager.update_player_info("gender", selected_gender)
	GameManager.update_player_info("height", height)
	GameManager.update_player_info("weight", weight)
	GameManager.update_player_info("age", age)

	SaveManager.save_player(GameManager.player_data)
	GameManager.save_current_user(nickname)


	print("사용자 정보 수정 완료")


	visible = false

	profile_updated.emit()


# =========================================
# 취소
# =========================================

func _on_cancel_button_pressed() -> void:
	visible = false


# =========================================
# 경고
# =========================================

func show_warning(message: String) -> void:
	warning_label.text = "! " + message + " !"
	warning_label.visible = true
