extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var door_animation_player: AnimationPlayer = $AnimationPlayer2

@onready var intro_group: Node2D = \
	$World/IntroGroup

@onready var start_button: TextureButton = \
	$World/IntroGroup/StartButton

@onready var dungeon_entry_button: TextureButton = \
	$World/RightGroup/DungeonEntryButton

@onready var food_entry_button: TextureButton = \
	$World/RightGroup/FoodEntryButton

@onready var workout_entry_button: TextureButton = \
	$World/RightGroup/WorkoutEntryButton

@onready var calendar_button: TextureButton = \
	$World/RightGroup/CalendarButton

@onready var collection_entry_button: TextureButton = \
	$World/RightGroup/CollectionEntryButton

@onready var dungeon_popup: Control = \
	$CanvasLayer/DungeonSelectPopup

@onready var diary_menu_popup: Control = \
	$CanvasLayer/DiaryMenuPopup

@onready var food_record_popup: Control = \
	$CanvasLayer/FoodRecordPopup

@onready var workout_record_popup: Control = \
	$CanvasLayer/WorkoutRecordPopup

@onready var collection_record_popup: Control = \
	$CanvasLayer/CollectionRecordPopup

@onready var profile_popup: Control = \
	$CanvasLayer/ProfilePopup

@onready var profile_edit_popup: Control = \
	$CanvasLayer/ProfileEditPopup

@onready var nickname_label: Label = \
	$World/LeftGroup/Board2/NicknameLabel

@onready var cheer_label: Label = \
	$World/LeftGroup/Board2/CheerLabel

@onready var bmr_label: Label = \
	$World/LeftGroup/Board2/BMRLabel

@onready var profile_button: TextureButton = \
	$World/LeftGroup/Board2/ProfileButton

@onready var goal_bar: Sprite2D = \
	$World/LeftGroup/GoalBar

@onready var goal_marker: ColorRect = \
	$World/LeftGroup/GoalMarker

@onready var status_label_in_progress: Label = \
	$World/LeftGroup/StatusLabel1

@onready var status_label_success: Label = \
	$World/LeftGroup/StatusLabel2

@onready var status_label_fail: Label = \
	$World/LeftGroup/StatusLabel3

@onready var left_group: Node2D = \
	$World/LeftGroup

@onready var right_group: Node2D = \
	$World/RightGroup

@onready var character: AnimatedSprite2D = \
	$World/Character

@onready var door_entry_point: Marker2D = \
	$World/DoorEntryPoint

@onready var camera_2d: Camera2D = \
	$Camera2D

@onready var door_camera_point: Marker2D = \
	$DoorCameraPoint

@onready var button_click_audio: AudioStreamPlayer = \
	$ButtonClickAudio

@onready var dungeon_door_audio: AudioStreamPlayer = \
	$DungeonDoorAudio

@onready var coin_label: Label = \
	$World/RightGroup/CoinCheck/CoinLabel

@onready var card_upgrade_button: Button = \
	$World/LeftGroup/CardUpgradeButton

@onready var coin_reward_popup = \
	$CoinRewardPopup

@onready var card_upgrade_popup = \
	$CardUpgradePopup

@onready var message_popup = \
	$MessagePopup


const DESSERT_SCENE: String = \
	"res://scenes/DessertKingdom.tscn"

const FAST_FOOD_SCENE: String = \
	"res://fast-food-city/Scenes/GameScene.tscn"

const BOSS_BATTLE_SCENE: String = \
	"res://scenes/boss_battle/BossBattle.tscn"


var home_opened: bool = false
var entering_dungeon: bool = false


func _ready() -> void:
	dungeon_popup.visible = false
	profile_popup.visible = false
	profile_edit_popup.visible = false

	setup_user_board()

	profile_button.pressed.connect(
		_on_profile_button_pressed
	)

	profile_popup.edit_requested.connect(
		_on_profile_edit_requested
	)

	profile_edit_popup.profile_updated.connect(
		_on_profile_updated
	)

	GameManager.daily_totals_changed.connect(
		update_goal_status
	)

	GameManager.coins_earned.connect(
		_on_coins_earned
	)

	card_upgrade_button.pressed.connect(
		_on_card_upgrade_button_pressed
	)

	_update_coin_label()

	# 홈 화면에 들어올 때마다 실제 기록(음식/운동)을 다시 합산해서 최신 상태로 그린다.
	GameManager.refresh_today_totals()

	start_button.pressed.connect(
		_on_start_button_pressed
	)

	dungeon_entry_button.pressed.connect(
		_on_dungeon_entry_button_pressed
	)

	food_entry_button.pressed.connect(
		_on_food_entry_button_pressed
	)

	workout_entry_button.pressed.connect(
		_on_workout_entry_button_pressed
	)

	calendar_button.pressed.connect(
		_on_calendar_button_pressed
	)

	collection_entry_button.pressed.connect(
		_on_collection_entry_button_pressed
	)

	dungeon_popup.dungeon_selected.connect(
		_on_dungeon_selected
	)

	character.play("idle")

	button_click_audio.stop()
	dungeon_door_audio.stop()

	# 캘린더 등 다른 화면에서 메인 홈 버튼을 눌러 돌아온 경우, "터치해 시작하기"
	# 인트로 화면부터 다시 보여주지 않고 이미 열려 있던 홈 화면 상태로 바로 보여준다.
	if GameManager.home_intro_shown:
		_show_home_opened_state()


func _show_home_opened_state() -> void:
	home_opened = true
	start_button.disabled = true
	intro_group.visible = false
	left_group.position = Vector2.ZERO
	right_group.position = Vector2.ZERO


# ================================
# 상단 사용자 보드 (닉네임 / 기초대사량)
# ================================

func setup_user_board() -> void:
	nickname_label.text = GameManager.player_data["nickname"]

	cheer_label.text = "오늘도 힘내자! BUFF UP!"

	var bmr := GameManager.calculate_bmr()

	bmr_label.text = "기초대사량: %.0f kcal" % bmr


func _on_profile_button_pressed() -> void:
	if entering_dungeon:
		return

	play_button_click_sound()

	profile_popup.show_profile()


func _on_profile_edit_requested() -> void:
	play_button_click_sound()

	profile_popup.visible = false
	profile_edit_popup.open_edit()


func _on_profile_updated() -> void:
	setup_user_board()
	profile_popup.show_profile()


# ================================
# 코인 (오른쪽 위 코인 표시 + 획득 알림)
# ================================

func _update_coin_label() -> void:
	coin_label.text = str(BossSave.coins)


func _on_coins_earned(amount: int, reason: String) -> void:
	_update_coin_label()
	coin_reward_popup.show_reward(amount, reason)


func _on_card_upgrade_button_pressed() -> void:
	play_button_click_sound()
	card_upgrade_popup.open_shop()


# ================================
# 오늘의 목표 달성 상태 (진행중 / 달성 / 실패) + 게이지 바 위의 빨간 마커
# 밤 10시(22시)가 지나야 달성/실패가 확정되고, 그 전에는 항상 "진행중"으로 표시한다.
# 섭취 칼로리 - 기초대사량 - 운동 소모 칼로리가 -500~-200kcal 사이면 목표 달성.
# ================================

const GOAL_MIN: float = -500.0
const GOAL_MAX: float = -200.0


func update_goal_status() -> void:
	var balance := GameManager.get_today_balance()
	var hour: int = Time.get_time_dict_from_system()["hour"]

	var achieved := balance >= GOAL_MIN and balance <= GOAL_MAX

	status_label_in_progress.visible = hour < 22
	status_label_success.visible = hour >= 22 and achieved
	status_label_fail.visible = hour >= 22 and not achieved

	_update_goal_marker(balance)

	GameManager.try_award_goal_reward()


func _update_goal_marker(balance: float) -> void:
	var half_width: float = (goal_bar.region_rect.size.x * goal_bar.scale.x) / 2.0
	var half_height: float = (goal_bar.region_rect.size.y * goal_bar.scale.y) / 2.0
	var bar_left: float = goal_bar.position.x - half_width
	var bar_right: float = goal_bar.position.x + half_width

	var clamped := clampf(balance, GOAL_MIN, GOAL_MAX)
	var ratio := (clamped - GOAL_MIN) / (GOAL_MAX - GOAL_MIN)
	var marker_x := lerpf(bar_left, bar_right, ratio)

	var marker_half_width := (goal_marker.offset_right - goal_marker.offset_left) / 2.0
	goal_marker.offset_left = marker_x - marker_half_width
	goal_marker.offset_right = marker_x + marker_half_width

	# 마커 세로 길이를 게이지 바의 실제 높이에 정확히 맞춘다.
	goal_marker.offset_top = goal_bar.position.y - half_height
	goal_marker.offset_bottom = goal_bar.position.y + half_height


func _on_food_entry_button_pressed() -> void:
	if not home_opened:
		return
	_close_other_pages(food_record_popup)
	food_record_popup.open_page()


func _on_workout_entry_button_pressed() -> void:
	if not home_opened:
		return
	_close_other_pages(workout_record_popup)
	workout_record_popup.open_page()


func _on_calendar_button_pressed() -> void:
	if not home_opened:
		return
	_close_other_pages(diary_menu_popup)
	diary_menu_popup.open_page()


func _on_collection_entry_button_pressed() -> void:
	if not home_opened:
		return
	_close_other_pages(collection_record_popup)
	collection_record_popup.open_page()


# 식단기록/운동기록/다이어리/도감 페이지가 같은 자리에 펼쳐지므로, 하나를 열 때
# 나머지는 겹치지 않도록 닫아준다.
func _close_other_pages(except_popup: Control) -> void:
	for popup in [diary_menu_popup, food_record_popup, workout_record_popup, collection_record_popup]:
		if popup != except_popup:
			popup.close_page()


func _on_start_button_pressed() -> void:
	if home_opened:
		return

	play_button_click_sound()

	home_opened = true
	start_button.disabled = true
	GameManager.home_intro_shown = true
	animation_player.play("open_home")


func _on_dungeon_entry_button_pressed() -> void:
	if not home_opened:
		return

	if entering_dungeon:
		return

	play_button_click_sound()

	if not GameManager.is_dungeon_time_open():
		message_popup.show_message(
			"아직 입장할 수 없어요",
			"던전은 밤 10시 이후에 입장할 수 있어요!"
		)
		return

	dungeon_popup.visible = true


func _on_dungeon_selected(dungeon_id: String) -> void:
	if entering_dungeon:
		return

	play_button_click_sound()

	if GameManager.has_free_dungeon_play_today():
		GameManager.use_free_dungeon_play()
	else:
		if BossSave.spend(GameManager.DUNGEON_REPLAY_COST):
			_update_coin_label()
		else:
			message_popup.show_message(
				"코인이 부족해요",
				"오늘 무료 입장은 이미 사용했어요.\n다시 입장하려면 코인 %d개가 필요해요." % GameManager.DUNGEON_REPLAY_COST
			)
			return

	match dungeon_id:
		"dessert":
			entering_dungeon = true

			await _hide_home_groups()
			await _move_character_to_door()
			await _play_door_glow()
			await _play_dungeon_door_sound()
			_change_to_dessert_scene()

		"fast_food":
			entering_dungeon = true

			await _hide_home_groups()
			await _move_character_to_door()
			await _play_door_glow()
			await _play_dungeon_door_sound()
			_change_to_fast_food_scene()

		"salad":
			entering_dungeon = true

			await _hide_home_groups()
			await _move_character_to_door()
			await _play_door_glow()
			await _play_dungeon_door_sound()
			_enter_boss_battle("salad")

		_:
			push_warning("알 수 없는 던전 ID: " + dungeon_id)


func _hide_home_groups() -> void:
	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		left_group,
		"position:x",
		left_group.position.x - 700.0,
		0.4
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.tween_property(
		right_group,
		"position:x",
		right_group.position.x + 700.0,
		0.4
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await tween.finished

	left_group.visible = false
	right_group.visible = false


func _move_character_to_door() -> void:
	character.flip_h = false
	character.play("walk")

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		character,
		"global_position",
		door_entry_point.global_position,
		4.0
	).set_trans(Tween.TRANS_LINEAR)

	tween.tween_property(
		camera_2d,
		"global_position",
		door_camera_point.global_position,
		4.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	character.play("idle")


func _play_door_glow() -> void:
	if not door_animation_player.has_animation("door_glow"):
		push_error("AnimationPlayer2에 door_glow 애니메이션이 없습니다.")
		return

	door_animation_player.play("door_glow")
	await door_animation_player.animation_finished

	await get_tree().create_timer(0.2).timeout


func _play_dungeon_door_sound() -> void:
	dungeon_door_audio.play()
	await get_tree().create_timer(0.6).timeout


func play_button_click_sound() -> void:
	button_click_audio.play()


func _change_to_dessert_scene() -> void:
	var error := get_tree().change_scene_to_file(
		DESSERT_SCENE
	)

	if error != OK:
		push_error(
			"디저트 왕국 씬을 열지 못했습니다: "
			+ DESSERT_SCENE
		)


func _change_to_fast_food_scene() -> void:
	var error := get_tree().change_scene_to_file(
		FAST_FOOD_SCENE
	)

	if error != OK:
		push_error(
			"패스트푸드 시티 씬을 열지 못했습니다: "
			+ FAST_FOOD_SCENE
		)


# 아직 던전 레벨이 없는 샐러드 가든은 보스전으로 바로 입장한다.
func _enter_boss_battle(boss_id: String) -> void:
	GameManager.pending_boss_id = boss_id

	var error := get_tree().change_scene_to_file(
		BOSS_BATTLE_SCENE
	)

	if error != OK:
		push_error(
			"보스전 씬을 열지 못했습니다: "
			+ BOSS_BATTLE_SCENE
		)
