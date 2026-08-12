extends Control

# 이 팝업이 어느 던전에 임베드되었는지에 따라 "사용하기(재도전)" 버튼이
# 다시 시작할 씬. 던전 씬이 직접 설정하지 않으면 디저트 왕국으로 재시작한다
# (기존 동작과 동일하게 유지하기 위한 기본값).
@export var retry_scene_path: String = "res://scenes/DessertKingdom.tscn"

@onready var retry_popup: Control = $RetryPopup

@onready var main_home_button: TextureButton = $MainHomeButton1
@onready var play_again_button: TextureButton = $PlayagainButton

@onready var use_button: TextureButton = $RetryPopup/Panel/UseButton
@onready var cancel_button: TextureButton = $RetryPopup/Panel/CancelButton

@onready var coin_spin_1: AnimatedSprite2D = $RetryPopup/Panel/CoinSpin1
@onready var coin_spin_2: AnimatedSprite2D = $RetryPopup/Panel/CoinSpin2

# ================================
# 오디오
# ================================

@onready var button_click_audio: AudioStreamPlayer = $ButtonClickAudio
@onready var game_over_audio: AudioStreamPlayer = $GameOverAudio


func _ready() -> void:
	# 처음에는 코인 팝업 숨기기
	retry_popup.visible = false

	# 버튼 연결
	main_home_button.pressed.connect(_on_main_home_pressed)
	play_again_button.pressed.connect(_on_play_again_pressed)
	use_button.pressed.connect(_on_use_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

	# 코인 회전
	coin_spin_1.play()
	coin_spin_2.play()

	# 중요!
	# 여기서는 GameOverAudio를 재생하지 않음
	game_over_audio.stop()

	print("GameOverScene 준비 완료")


# ================================
# 실제 Game Over가 발생했을 때
# ================================

func show_game_over() -> void:
	visible = true

	# Game Over 효과음
	game_over_audio.play()

	print("Game Over 화면 표시 + 효과음 재생")


# ================================
# 버튼 클릭 효과음
# ================================

func play_button_click_sound() -> void:
	button_click_audio.play()


# ================================
# Main Home
# ================================

func _on_main_home_pressed() -> void:
	play_button_click_sound()

	GameManager.home_intro_shown = true

	print("Main Home 버튼 눌림")

	await get_tree().create_timer(0.12).timeout

	get_tree().change_scene_to_file(
		"res://scenes/HomeScene.tscn"
	)


# ================================
# Play Again
# ================================

func _on_play_again_pressed() -> void:
	play_button_click_sound()

	print("Play Again 버튼 눌림")

	retry_popup.visible = true


# ================================
# 취소
# ================================

func _on_cancel_pressed() -> void:
	play_button_click_sound()

	print("취소 버튼 눌림")

	retry_popup.visible = false


# ================================
# 사용하기
# ================================

func _on_use_pressed() -> void:
	play_button_click_sound()

	print("사용하기 버튼 눌림")

	await get_tree().create_timer(0.12).timeout

	get_tree().change_scene_to_file(
		retry_scene_path
	)
