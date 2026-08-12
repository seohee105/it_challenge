extends Control

signal nickname_saved(nickname: String)

@onready var nickname_input: LineEdit = $NicknameInput
@onready var warning_label: Label = $WarningLabel
@onready var confirm_button: TextureButton = $ConfirmButton

var placeholder_tween: Tween

# 원하는 Placeholder 기본 색
var placeholder_color: Color = Color(0.55, 0.45, 0.35, 1.0)


func _ready() -> void:
	visible = false
	warning_label.visible = false

	nickname_input.placeholder_text = "닉네임을 입력해주세요"

	confirm_button.pressed.connect(
		_on_confirm_button_pressed
	)

	nickname_input.focus_entered.connect(
		_on_nickname_focus_entered
	)

	nickname_input.focus_exited.connect(
		_on_nickname_focus_exited
	)

	start_placeholder_blink()


# =========================================
# Placeholder 글자만 깜빡이기
# =========================================

func start_placeholder_blink() -> void:
	if placeholder_tween != null:
		placeholder_tween.kill()

	var bright_color := placeholder_color
	bright_color.a = 1.0

	var faded_color := placeholder_color
	faded_color.a = 0.25

	nickname_input.add_theme_color_override(
		"font_placeholder_color",
		bright_color
	)

	placeholder_tween = create_tween()
	placeholder_tween.set_loops()

	placeholder_tween.tween_method(
		_set_placeholder_color,
		bright_color,
		faded_color,
		0.65
	)

	placeholder_tween.tween_method(
		_set_placeholder_color,
		faded_color,
		bright_color,
		0.65
	)


func _set_placeholder_color(color: Color) -> void:
	nickname_input.add_theme_color_override(
		"font_placeholder_color",
		color
	)


# =========================================
# 입력창 클릭
# =========================================

func _on_nickname_focus_entered() -> void:
	# 깜빡임 정지
	if placeholder_tween != null:
		placeholder_tween.kill()

	placeholder_tween = null

	# Placeholder 문구 숨김
	nickname_input.placeholder_text = ""


# =========================================
# 입력창에서 벗어났을 때
# =========================================

func _on_nickname_focus_exited() -> void:
	# 아무것도 입력하지 않았다면 다시 표시
	if nickname_input.text.strip_edges() == "":
		nickname_input.placeholder_text = "닉네임을 입력해주세요"

		start_placeholder_blink()


# =========================================
# 확인 버튼
# =========================================

func _on_confirm_button_pressed() -> void:
	warning_label.visible = false

	var nickname := nickname_input.text.strip_edges()

	if nickname == "":
		show_warning("닉네임을 입력해주세요.")
		return

	if nickname.length() > 10:
		show_warning("닉네임은 10자 이하로 입력해주세요.")
		return

	print("닉네임 입력 완료: ", nickname)

	nickname_saved.emit(nickname)

	visible = false


# =========================================
# 경고 메시지
# =========================================

func show_warning(message: String) -> void:
	warning_label.text = "! " + message + " !"
	warning_label.visible = true
