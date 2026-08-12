extends Control


# =========================================
# 노드
# =========================================

@onready var retry_button: Button = $RetryButton
@onready var home_button: Button = $HomeButton

@onready var popup: Control = $PopUp

@onready var use_button: TextureButton = $PopUp/Panel/UseButton
@onready var cancel_button: TextureButton = $PopUp/Panel/CancelButton

@onready var game_over_audio: AudioStreamPlayer = $GameOverAudio


# =========================================
# 시작
# =========================================

func _ready():

	# 처음에는 팝업 숨기기
	popup.hide()

	# 게임오버 효과음
	game_over_audio.play()


	# 다시 도전
	if not retry_button.pressed.is_connected(
		_on_retry_button_pressed
	):
		retry_button.pressed.connect(
			_on_retry_button_pressed
		)


	# 사용하기
	if not use_button.pressed.is_connected(
		_on_use_button_pressed
	):
		use_button.pressed.connect(
			_on_use_button_pressed
		)


	# 취소
	if not cancel_button.pressed.is_connected(
		_on_cancel_button_pressed
	):
		cancel_button.pressed.connect(
			_on_cancel_button_pressed
		)

	# 홈으로
	if not home_button.pressed.is_connected(
		_on_home_button_pressed
	):
		home_button.pressed.connect(
			_on_home_button_pressed
		)


# =========================================
# 다시 도전 버튼
# =========================================

func _on_retry_button_pressed():

	print("다시 도전하기")

	popup.show()


# =========================================
# 사용하기 버튼
# =========================================

func _on_use_button_pressed():

	print("사용하기")


	# 팝업 닫기
	popup.hide()


	# 패스트푸드 시티 다시 시작
	get_tree().change_scene_to_file(
		"res://fast-food-city/Scenes/GameScene.tscn"
	)


# =========================================
# 취소 버튼
# =========================================

func _on_cancel_button_pressed():

	print("취소")

	popup.hide()


# =========================================
# 홈 버튼
# =========================================

func _on_home_button_pressed():

	print("홈으로 이동")

	GameManager.home_intro_shown = true

	get_tree().change_scene_to_file(
		"res://scenes/HomeScene.tscn"
	)
