extends Control


# =========================================
# 카메라
# =========================================

@onready var camera_2d: Camera2D = $World/Camera2D
@onready var ground_camera_point: Marker2D = $World/GroundCameraPoint


# =========================================
# 시작 UI
# =========================================

@onready var start_ui: Control = $CanvasLayer/StartUI
@onready var start_button: TextureButton = $CanvasLayer/StartUI/StartButton


# =========================================
# 튜토리얼 / 정보 입력
# =========================================

@onready var tutorial_textbox = $CanvasLayer/TutorialTextBox
@onready var login_scene = $CanvasLayer/LoginScene
@onready var nickname_popup = $CanvasLayer/NicknamePopup


# =========================================
# 화면 전환
# =========================================

@onready var fade_rect: ColorRect = $CanvasLayer/FadeRect


# =========================================
# 캐릭터
# =========================================

@onready var girl_character: AnimatedSprite2D = $World/GirlCharacter
@onready var boy_character: AnimatedSprite2D = $World/BoyCharacter


# 캐릭터가 에디터에서 가지고 있던 원래 크기
var girl_original_scale: Vector2
var boy_original_scale: Vector2


# =========================================
# 상태
# =========================================

var is_camera_moving: bool = false

var saved_gender: String = ""
var saved_height: float = 0.0
var saved_weight: float = 0.0
var saved_age: int = 0
var saved_nickname: String = ""


# =========================================
# 시작
# =========================================

func _ready() -> void:
	# =========================================
	# 이미 저장된 사용자 정보가 있으면 로그인 과정을
	# 건너뛰고 바로 홈 화면으로 이동한다.
	# =========================================

	if GameManager.load_saved_profile():
		GameManager.check_new_day()
		GameManager.home_intro_shown = true
		get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")
		return


	# =========================================
	# 캐릭터 원래 크기 저장
	# =========================================

	girl_original_scale = girl_character.scale
	boy_original_scale = boy_character.scale


	# =========================================
	# 시작 화면
	# =========================================

	start_ui.visible = true

	tutorial_textbox.visible = false
	login_scene.visible = false
	nickname_popup.visible = false


	# =========================================
	# 캐릭터 처음에는 숨김
	# =========================================

	girl_character.visible = false
	boy_character.visible = false

	girl_character.modulate.a = 1.0
	boy_character.modulate.a = 1.0


	# =========================================
	# FadeRect
	# 처음에는 완전히 투명
	# =========================================

	fade_rect.visible = true
	fade_rect.modulate.a = 0.0


	# =========================================
	# 카메라
	# =========================================

	camera_2d.enabled = true


	# =========================================
	# 시작 버튼
	# =========================================

	start_button.pressed.connect(
		_on_start_button_pressed
	)


	# =========================================
	# LoginScene 저장 완료 신호
	# =========================================

	login_scene.profile_saved.connect(
		_on_profile_saved
	)


	# =========================================
	# NicknamePopup 저장 완료 신호
	# =========================================

	nickname_popup.nickname_saved.connect(
		_on_nickname_saved
	)


	print("StartScene 준비 완료")


# =========================================
# 터치해 시작하기
# =========================================

func _on_start_button_pressed() -> void:
	if is_camera_moving:
		return

	is_camera_moving = true

	start_button.disabled = true


	# =========================================
	# 로고 + 터치해 시작하기 숨김
	# =========================================

	start_ui.visible = false

	print("카메라 이동 시작")


	# =========================================
	# 카메라 아래로 이동
	# =========================================

	await move_camera_to_ground()

	print("땅 화면 도착!")


	# 땅 화면 잠깐 보여주기
	await get_tree().create_timer(1.0).timeout


	# =========================================
	# 첫 번째 문장
	# =========================================

	tutorial_textbox.visible = true

	await tutorial_textbox.show_text(
		"본격적인 다이어터가 되기 위해선\n기본 정보가 필요합니다."
	)

	await tutorial_textbox.next_pressed


	# 문장 사이 잠깐 쉬기
	await get_tree().create_timer(0.5).timeout


	# =========================================
	# 두 번째 문장
	# =========================================

	await tutorial_textbox.show_text(
		"정보를 입력해주세요!"
	)

	await tutorial_textbox.next_pressed


	# =========================================
	# TextBox 종료
	# =========================================

	tutorial_textbox.visible = false

	await get_tree().create_timer(0.3).timeout


	# =========================================
	# LoginScene 표시
	# =========================================

	login_scene.visible = true

	print("LoginScene 표시")


# =========================================
# LoginScene 저장 완료
# =========================================

func _on_profile_saved(
	gender: String,
	height: float,
	weight: float,
	age: int
) -> void:

	print("StartScene에서 사용자 정보 받음!")


	# =========================================
	# 기본 정보 임시 저장
	# =========================================

	saved_gender = gender
	saved_height = height
	saved_weight = weight
	saved_age = age


	print("========================")
	print("성별: ", saved_gender)
	print("키: ", saved_height)
	print("몸무게: ", saved_weight)
	print("나이: ", saved_age)
	print("========================")


	# =========================================
	# LoginScene 숨기기
	# =========================================

	login_scene.visible = false


	# 캐릭터 생성 전에 잠깐 여유
	await get_tree().create_timer(0.3).timeout


	# =========================================
	# 캐릭터 초기화
	# =========================================

	girl_character.visible = false
	boy_character.visible = false

	girl_character.modulate.a = 1.0
	boy_character.modulate.a = 1.0

	girl_character.scale = girl_original_scale
	boy_character.scale = boy_original_scale


	# =========================================
	# 성별에 따라 캐릭터 생성
	# =========================================

	if gender == "female":
		print("여자 캐릭터 생성 시작!")

		await show_character_spawn(
			girl_character,
			girl_original_scale
		)

		print("여자 캐릭터 생성 완료!")


	elif gender == "male":
		print("남자 캐릭터 생성 시작!")

		await show_character_spawn(
			boy_character,
			boy_original_scale
		)

		print("남자 캐릭터 생성 완료!")


	else:
		push_warning(
			"알 수 없는 성별 값: " + gender
		)

		return


	# 캐릭터를 잠깐 보여줌
	await get_tree().create_timer(0.5).timeout


	# =========================================
	# 캐릭터 생성 안내
	# =========================================

	tutorial_textbox.visible = true

	await tutorial_textbox.show_text(
		"사용자의 캐릭터가 생성되었습니다!\n닉네임을 설정해주세요."
	)


	# >> 클릭 기다리기
	await tutorial_textbox.next_pressed


	# =========================================
	# TextBox 숨기기
	# =========================================

	tutorial_textbox.visible = false

	await get_tree().create_timer(0.3).timeout


	# =========================================
	# 닉네임 입력창 표시
	# =========================================

	nickname_popup.visible = true

	print("NicknamePopup 표시")


# =========================================
# 캐릭터 생성 연출
#
# 작고 희미한 상태
#       ↓
# 커지면서 선명해짐
#       ↓
# 원래 크기로 안착
# =========================================

func show_character_spawn(
	target_character: AnimatedSprite2D,
	original_scale: Vector2
) -> void:

	# =========================================
	# 시작 상태
	# =========================================

	target_character.visible = true

	# 투명하게 시작
	target_character.modulate.a = 0.0

	# 원래 크기의 70%
	target_character.scale = original_scale * 0.7

	# Idle 애니메이션
	target_character.play("Idle")


	# 살짝 기다린 뒤 등장
	await get_tree().create_timer(0.15).timeout


	# =========================================
	# 등장 Tween
	# =========================================

	var tween := create_tween()

	tween.set_parallel(true)


	# =========================================
	# 투명 → 선명
	# =========================================

	tween.tween_property(
		target_character,
		"modulate:a",
		1.0,
		1.2
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_OUT
	)


	# =========================================
	# 작게 → 원래 크기
	# =========================================

	tween.tween_property(
		target_character,
		"scale",
		original_scale,
		1.2
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)


	await tween.finished


	# 최종 상태 고정
	target_character.modulate.a = 1.0
	target_character.scale = original_scale


# =========================================
# 닉네임 입력 완료
# =========================================

func _on_nickname_saved(nickname: String) -> void:
	# =========================================
	# 닉네임 저장
	# =========================================

	saved_nickname = nickname

	print("닉네임 저장 완료: ", saved_nickname)


	# =========================================
	# 실제 사용자 프로필 저장
	# =========================================

	GameManager.update_player_info("nickname", saved_nickname)
	GameManager.update_player_info("gender", saved_gender)
	GameManager.update_player_info("height", saved_height)
	GameManager.update_player_info("weight", saved_weight)
	GameManager.update_player_info("age", saved_age)

	GameManager.check_new_day()

	SaveManager.save_player(GameManager.player_data)
	GameManager.save_current_user(saved_nickname)


	# NicknamePopup 숨기기
	nickname_popup.visible = false


	# 잠깐 기다렸다가 마지막 메시지
	await get_tree().create_timer(0.5).timeout


	# =========================================
	# 마지막 TutorialTextBox
	# =========================================

	tutorial_textbox.visible = true

	await tutorial_textbox.show_text(
		"이제 당신은 진정한 다이어터가 되었습니다!\n다이어트 모험을 떠나봅시다!"
	)


	# 마지막 >> 기다리기
	await tutorial_textbox.next_pressed


	# TextBox 숨기기
	tutorial_textbox.visible = false


	print("========================")
	print("튜토리얼 완료!")
	print("닉네임: ", saved_nickname)
	print("성별: ", saved_gender)
	print("키: ", saved_height)
	print("몸무게: ", saved_weight)
	print("나이: ", saved_age)
	print("========================")


	# =========================================
	# StartScene → 검은 화면
	# =========================================

	await fade_to_black()


	# =========================================
	# HomeScene 열린 상태로 시작
	# =========================================

	GameManager.home_intro_shown = true


	# =========================================
	# HomeScene 전환
	# =========================================

	print("HomeScene으로 이동!")

	get_tree().change_scene_to_file(
		"res://scenes/HomeScene.tscn"
	)


# =========================================
# StartScene Fade Out
# 화면 → 검은색
# =========================================

func fade_to_black() -> void:
	# FadeRect를 확실히 화면 위에 표시
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0


	var tween := create_tween()


	tween.tween_property(
		fade_rect,
		"modulate:a",
		1.0,
		0.8
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN_OUT
	)


	await tween.finished


# =========================================
# 카메라 이동
# =========================================

func move_camera_to_ground() -> void:
	var tween := create_tween()


	tween.tween_property(
		camera_2d,
		"global_position",
		ground_camera_point.global_position,
		3.0
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN_OUT
	)


	await tween.finished
