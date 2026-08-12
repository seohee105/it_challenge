extends CharacterBody2D


# =========================================
# 이동 설정
# =========================================

@export var move_speed: float = 400.0
@export var jump_force: float = -600.0
@export var gravity: float = 1200.0


# =========================================
# 낙사
# =========================================

@export var fall_game_over_y: float = 1000.0


# =========================================
# 공격 연출 설정
# =========================================

@export var hit_pause_time: float = 0.8


# =========================================
# 점프
# =========================================

var jump_count: int = 0
var is_double_jumping: bool = false


# =========================================
# HP
# =========================================

var hp: int = 100
var is_game_over: bool = false


# =========================================
# 공격
# =========================================

var has_sword: bool = false
var is_attacking: bool = false
var sword_time: float = 0.0

var attack_hit_confirmed: bool = false


# =========================================
# 방패
# =========================================

var shield_active: bool = false


# =========================================
# 이동 가능 여부
# =========================================

var can_move: bool = false


# =========================================
# 게임 시작 상태
# =========================================

var game_started: bool = false


# =========================================
# Player 노드
# =========================================

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var body_collision: CollisionShape2D = $BodyCollision

@onready var item_detector: Area2D = $ItemDetector

@onready var pickup_collision: CollisionShape2D = \
	$ItemDetector/PickupCollision

@onready var attack_area: Area2D = $AttackArea

@onready var attack_collision: CollisionShape2D = \
	$AttackArea/AttackCollision

@onready var shield_effect = $ShieldEffect


# =========================================
# UI
# =========================================

@onready var life_bar: TextureProgressBar = \
	$"../CanvasLayer/GaugeUI/LifeGauge"

@onready var jump_button: TextureButton = \
	$"../CanvasLayer/JumpButtonUI/JumpButton"

@onready var attack_button_ui: Control = \
	$"../CanvasLayer/AttackButtonUI"

@onready var attack_button: TextureButton = \
	$"../CanvasLayer/AttackButtonUI/TextureButton"


# =========================================
# Audio
# =========================================

@onready var bgm: AudioStreamPlayer = $"../BGM"

@onready var jump_sfx: AudioStreamPlayer = $"../JumpSFX"

@onready var item_get_audio: AudioStreamPlayer = \
	$"../ItemGetAudio"

@onready var slash_audio: AudioStreamPlayer = \
	$"../SlashAudio"

@onready var shield_hit_audio: AudioStreamPlayer = \
	$"../ShieldHitAudio"

@onready var heart_fever_audio: AudioStreamPlayer = \
	$"../HeartFeverAudio"


# =========================================
# 시작
# =========================================

func _ready():

	# =========================================
	# 게임 시작 전 상태
	# =========================================

	game_started = false
	can_move = false

	velocity = Vector2.ZERO


	# =========================================
	# LifeTimer
	# =========================================

	# READY / GAME START 동안에는
	# 게이지 감소하지 않음
	$LifeTimer.stop()


	# =========================================
	# LifeGauge
	# =========================================

	life_bar.min_value = 0
	life_bar.max_value = 100
	life_bar.value = hp


	# =========================================
	# UI 초기화
	# =========================================

	attack_button_ui.hide()

	shield_effect.hide()


	# =========================================
	# AttackArea 초기화
	# =========================================

	attack_area.monitoring = false
	attack_area.monitorable = true


	# =========================================
	# 모바일 버튼 Focus 제거
	# =========================================

	jump_button.focus_mode = Control.FOCUS_NONE
	attack_button.focus_mode = Control.FOCUS_NONE


	# =========================================
	# 점프 버튼 연결
	# =========================================

	if not jump_button.pressed.is_connected(
		_on_jump_button_pressed
	):
		jump_button.pressed.connect(
			_on_jump_button_pressed
		)


	# =========================================
	# 공격 버튼 연결
	# =========================================

	if not attack_button.pressed.is_connected(
		_on_attack_pressed
	):
		attack_button.pressed.connect(
			_on_attack_pressed
		)


	# =========================================
	# AttackArea 연결
	# =========================================

	if not attack_area.body_entered.is_connected(
		_on_attack_area_body_entered
	):
		attack_area.body_entered.connect(
			_on_attack_area_body_entered
		)


	# =========================================
	# 시작 애니메이션
	# =========================================

	animated_sprite.stop()
	animated_sprite.frame = 0
	animated_sprite.play("Idle")


# =========================================
# 이동
# =========================================

func _physics_process(delta):


	# =========================================
	# READY / GAME START 대기 중
	# =========================================

	if not game_started:

		# 가로 이동 완전 정지
		velocity.x = 0


		# 바닥에 아직 안 닿아 있다면
		# 중력만 적용
		if not is_on_floor():

			velocity.y += gravity * delta

		else:

			velocity.y = 0


		move_and_slide()


		# 무조건 Idle 유지
		if animated_sprite.animation != "Idle":

			animated_sprite.play("Idle")


		# 실제 게임 로직 실행하지 않음
		return


	# =========================================
	# 중력
	# =========================================

	if not is_on_floor():

		velocity.y += gravity * delta


	# =========================================
	# 자동 달리기
	# =========================================

	if can_move:

		velocity.x = move_speed

	else:

		velocity.x = 0


	# =========================================
	# PC 점프 (디저트 왕국과 동일하게 "jump" 액션 사용)
	# =========================================

	if Input.is_action_just_pressed("jump"):

		try_jump()


	# =========================================
	# PC 공격 (디저트 왕국과 동일하게 "attack" 액션 사용)
	# =========================================

	if (
		Input.is_action_just_pressed("attack")
		and has_sword
		and not is_attacking
	):

		_on_attack_pressed()


	# =========================================
	# 실제 이동
	# =========================================

	move_and_slide()


	# =========================================
	# 착지 후 다시 확인
	# =========================================

	if is_on_floor():

		jump_count = 0
		is_double_jumping = false


	# =========================================
	# 애니메이션
	# =========================================

	update_animation()


	# =========================================
	# 낙사
	# =========================================

	if global_position.y > fall_game_over_y:

		game_over()


	# =========================================
	# 검 사용 시간
	# =========================================

	if has_sword:

		sword_time -= delta


		if sword_time <= 0:

			has_sword = false
			sword_time = 0.0

			attack_button_ui.hide()

			attack_area.monitoring = false


# =========================================
# 점프
# =========================================

func try_jump():

	# 시작 연출 중 점프 불가
	if not game_started:
		return


	if not can_move:
		return


	# =========================================
	# 첫 점프
	# =========================================

	if is_on_floor():

		velocity.y = jump_force

		jump_count = 1
		is_double_jumping = false


		jump_sfx.play()


		return


	# =========================================
	# 더블 점프 (디저트 왕국과 동일하게 1단과 같은 점프력 사용)
	# =========================================

	if jump_count == 1:

		velocity.y = jump_force

		jump_count = 2
		is_double_jumping = true


		jump_sfx.play()


		if not is_attacking:

			animated_sprite.stop()
			animated_sprite.frame = 0
			animated_sprite.play("DoubleJump")


# =========================================
# 모바일 점프 버튼
# =========================================

func _on_jump_button_pressed():

	try_jump()


# =========================================
# 애니메이션
# =========================================

func update_animation():


	# =========================================
	# 게임 시작 전
	# =========================================

	if not game_started:

		if animated_sprite.animation != "Idle":

			animated_sprite.play("Idle")

		return


	# =========================================
	# 공격 중
	# =========================================

	if is_attacking:
		return


	# =========================================
	# 더블 점프
	# =========================================

	if is_double_jumping and not is_on_floor():

		if animated_sprite.animation != "DoubleJump":

			animated_sprite.play("DoubleJump")

		return


	# =========================================
	# 검을 들고 있을 때
	# =========================================

	if has_sword:


		# 검 들고 점프
		if not is_on_floor():

			if animated_sprite.animation != "GumJump":

				animated_sprite.play("GumJump")


		# 검 들고 달리기
		else:

			if animated_sprite.animation != "GumWalk":

				animated_sprite.play("GumWalk")


		return


	# =========================================
	# 일반 상태
	# =========================================

	if not is_on_floor():

		if animated_sprite.animation != "Jump":

			animated_sprite.play("Jump")


	elif can_move:

		if animated_sprite.animation != "Walk":

			animated_sprite.play("Walk")


	else:

		if animated_sprite.animation != "Idle":

			animated_sprite.play("Idle")


# =========================================
# HP 자동 감소
# =========================================

func _on_life_timer_timeout():

	# 게임 시작 전에는 감소하지 않음
	if not game_started:
		return


	if shield_active:
		return


	hp -= 3


	if hp < 0:

		hp = 0


	life_bar.value = hp


	if hp <= 0:

		game_over()


# =========================================
# 검 획득
# =========================================

func show_attack_button():

	has_sword = true


	attack_button_ui.show()


	print("공격 가능!")


	sword_time += 6.0


	print(
		"남은 공격시간 : ",
		sword_time
	)


# =========================================
# 공격
# =========================================

func _on_attack_pressed():

	# =========================================
	# 시작 연출 중 공격 불가
	# =========================================

	if not game_started:
		return


	# 검이 없으면 공격 불가
	if not has_sword:
		return


	# 이미 공격 중
	if is_attacking:
		return


	# =========================================
	# 공격 시작
	# =========================================

	is_attacking = true

	attack_hit_confirmed = false


	# =========================================
	# 공격 애니메이션
	# =========================================

	var attack_animation: String


	if is_on_floor():

		attack_animation = "GumWalkAttack"

	else:

		attack_animation = "GumJumpAttack"


	animated_sprite.stop()
	animated_sprite.frame = 0
	animated_sprite.play(attack_animation)


	# =========================================
	# 공격 판정 ON
	# =========================================

	attack_area.monitoring = true


	# 충돌 판정 업데이트
	await get_tree().physics_frame
	await get_tree().physics_frame


	# =========================================
	# 공격 범위 내 적 확인
	# =========================================

	var enemies = attack_area.get_overlapping_bodies()


	for enemy in enemies:

		_try_hit_enemy(enemy)


	# =========================================
	# 적을 실제로 맞혔을 때만 정지
	# =========================================

	if attack_hit_confirmed:

		can_move = false
		velocity.x = 0


	# =========================================
	# 공격 애니메이션 종료 대기
	# =========================================

	await animated_sprite.animation_finished


	# =========================================
	# 적 처치 연출 대기
	# =========================================

	if attack_hit_confirmed:

		await get_tree().create_timer(
			hit_pause_time
		).timeout


	# =========================================
	# 공격 종료
	# =========================================

	attack_area.monitoring = false

	is_attacking = false


	# =========================================
	# 다시 이동
	# =========================================

	if attack_hit_confirmed and not is_game_over:

		can_move = true


	attack_hit_confirmed = false


	update_animation()


# =========================================
# AttackArea 진입
# =========================================

func _on_attack_area_body_entered(body):

	if not game_started:
		return


	if not is_attacking:
		return


	_try_hit_enemy(body)


# =========================================
# 적 공격 처리
# =========================================

func _try_hit_enemy(enemy):

	if enemy == null:
		return


	if not enemy.has_method("take_hit"):
		return


	if attack_hit_confirmed:
		return


	attack_hit_confirmed = true


	print(
		"공격 성공 : ",
		enemy.name
	)


	# Slash 효과음
	slash_audio.play()


	enemy.take_hit()


# =========================================
# 방패 활성화
# =========================================

func activate_shield():

	if shield_active:
		return


	shield_active = true


	print("방패 활성!")


	# =========================================
	# 방패 표시
	# =========================================

	shield_effect.show()

	shield_effect.modulate.a = 1.0

	shield_effect.scale = Vector2(
		0.3,
		0.3
	)


	# =========================================
	# 6초 유지
	# =========================================

	await get_tree().create_timer(
		6.0
	).timeout


	# =========================================
	# 서서히 사라짐
	# =========================================

	var disappear_tween = create_tween()


	disappear_tween.tween_property(
		shield_effect,
		"modulate:a",
		0.0,
		0.5
	)


	await disappear_tween.finished


	# =========================================
	# 종료
	# =========================================

	shield_active = false

	shield_effect.hide()

	shield_effect.modulate.a = 1.0


	print("방패 종료")


# =========================================
# 게임오버
# =========================================

func game_over():

	if is_game_over:
		return


	is_game_over = true

	can_move = false

	attack_area.monitoring = false


	print("GAME OVER")


	# =========================================
	# BGM 정지 (디저트 왕국과 동일)
	# =========================================

	if bgm.playing:
		bgm.stop()


	# =========================================
	# 디저트 왕국과 동일한 공용 게임오버 팝업 표시
	# =========================================

	var game = get_tree().current_scene

	if game.has_method("show_game_over"):
		game.show_game_over()


# =========================================
# 보스 문 입장
# =========================================

func enter_boss_door(door_pos):

	can_move = false

	attack_area.monitoring = false

	attack_button_ui.hide()


	# =========================================
	# 문으로 이동할 때 애니메이션
	# =========================================

	if has_sword:

		animated_sprite.play("GumWalk")

	else:

		animated_sprite.play("Walk")


	# =========================================
	# 문 중앙까지 이동
	# =========================================

	var tween = create_tween()


	tween.tween_property(
		self,
		"global_position",
		Vector2(
			door_pos.x,
			global_position.y
		),
		0.8
	)


	await tween.finished


	# =========================================
	# 문 안쪽으로 이동
	# =========================================

	var tween2 = create_tween()


	tween2.tween_property(
		self,
		"global_position",
		Vector2(
			door_pos.x + 60,
			global_position.y
		),
		0.5
	)


	await tween2.finished


	modulate.a = 0.0


	await get_tree().create_timer(
		0.6
	).timeout


	# =========================================
	# 패스트푸드 시티 보스전으로 이동
	# =========================================

	GameManager.pending_boss_id = "fast_food"

	get_tree().change_scene_to_file(
		"res://scenes/boss_battle/BossBattle.tscn"
	)


# =========================================
# 아이템 획득 효과음
# =========================================

func play_item_get_audio():

	item_get_audio.play()


# =========================================
# 방패 충돌 효과음
# =========================================

func play_shield_hit_audio():

	shield_hit_audio.play()


# =========================================
# 하트 회복
# =========================================

func heal_with_heart(amount: int):

	var target_hp: int = min(
		hp + amount,
		100
	)


	if target_hp <= hp:
		return


	# =========================================
	# 회복 효과음
	# =========================================

	heart_fever_audio.play()


	# =========================================
	# 실제 HP 회복
	# =========================================

	hp = target_hp


	# =========================================
	# 게이지 부드럽게 회복
	# =========================================

	var heal_tween = create_tween()


	heal_tween.tween_property(
		life_bar,
		"value",
		float(target_hp),
		0.6
	)


	await heal_tween.finished


	heart_fever_audio.stop()


# =========================================
# 게임 시작 대기
# =========================================

func prepare_game_start():

	game_started = false

	can_move = false

	velocity = Vector2.ZERO


	# 게이지 감소 정지
	$LifeTimer.stop()


	# =========================================
	# Idle
	# =========================================

	animated_sprite.stop()
	animated_sprite.frame = 0
	animated_sprite.play("Idle")


	print("게임 시작 대기")


# =========================================
# 실제 게임 시작
# =========================================

func start_game():

	game_started = true

	can_move = true


	# 실제 게임 시작과 함께 게이지 감소
	$LifeTimer.start()


	# =========================================
	# Walk 시작
	# =========================================

	animated_sprite.stop()
	animated_sprite.frame = 0
	animated_sprite.play("Walk")


	print("실제 게임 시작!")
