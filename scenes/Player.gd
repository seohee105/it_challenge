extends CharacterBody2D

@export var move_speed: float = 400.0
@export var jump_force: float = -600.0
@export var gravity: float = 1200.0
@export var sword_duration: float = 8.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea

@onready var sword_ui: Control = $"../CanvasLayer/SwordUI"
@onready var sword_button: TextureButton = $"../CanvasLayer/SwordUI/SwordButton"

@onready var guard: Sprite2D = $Guard

@onready var sword_time_label: Label = $"../CanvasLayer/StatusUI/SwordTimeLabel"
@onready var shield_count_label: Label = $"../CanvasLayer/StatusUI/ShieldCountLabel"


# ================================
# 아이템 획득 효과 문구
# ================================

@onready var heart_fever_label: Label = $"../CanvasLayer/EffectText/HeartFever"
@onready var ten_label: Label = $"../CanvasLayer/EffectText/ten"
@onready var attack_buff_label: Label = $"../CanvasLayer/EffectText/AttackBuff"
@onready var shield_buff_label: Label = $"../CanvasLayer/EffectText/ShieldBuff"


# ================================
# 피격 효과 문구
# ================================

@onready var damage_text_label: Label = $"../CanvasLayer/EffectText/DamageText"
@onready var damage_amount_label: Label = $"../CanvasLayer/EffectText/DamageAmount"


@onready var jump_button: TextureButton = $"../CanvasLayer/JumpUI/JumpButton"


var has_sword: bool = false
var is_attacking: bool = false

# 실제로 적을 맞혔는지
var hit_enemy: bool = false

var has_shield: bool = false
var can_move: bool = true

# 검 남은 시간
var sword_time_left: float = 0.0


# ================================
# 더블점프
# ================================

var jump_count: int = 0
var max_jump_count: int = 2
var is_double_jumping: bool = false


# ================================
# 시작
# ================================

func _ready() -> void:
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)

	# 처음에는 검 버튼 숨기기
	sword_ui.visible = false

	# 모바일 공격 버튼
	sword_button.pressed.connect(_on_sword_button_pressed)

	# 모바일 점프 버튼
	jump_button.pressed.connect(_on_jump_button_pressed)

	# 처음에는 방패 숨기기
	guard.visible = false

	# 상태 Label 숨기기
	sword_time_label.visible = false
	shield_count_label.visible = false

	# 아이템 효과 문구 숨기기
	heart_fever_label.visible = false
	ten_label.visible = false
	attack_buff_label.visible = false
	shield_buff_label.visible = false

	# 피격 효과 문구 숨기기
	damage_text_label.visible = false
	damage_amount_label.visible = false


# ================================
# 매 프레임
# ================================

func _physics_process(delta: float) -> void:
	# ================================
	# 검 남은 시간
	# ================================
	if has_sword:
		sword_time_left -= delta
		sword_time_left = maxf(sword_time_left, 0.0)

		sword_time_label.text = "🗡️ %.1fs" % sword_time_left

		if sword_time_left <= 0.0:
			end_sword()


	# ================================
	# 게임 정지 상태
	# ================================
	if not can_move:
		velocity = Vector2.ZERO
		return


	# ================================
	# 착지하면 점프 횟수 초기화
	# ================================
	if is_on_floor():
		jump_count = 0

		if is_double_jumping:
			is_double_jumping = false


	# ================================
	# 중력
	# ================================
	if not is_on_floor():
		velocity.y += gravity * delta


	# ================================
	# 자동 이동
	# ================================
	if is_attacking and hit_enemy:
		velocity.x = 0.0
	else:
		velocity.x = move_speed


	# ================================
	# PC 점프
	# ================================
	if Input.is_action_just_pressed("jump"):
		try_jump()


	# ================================
	# PC 공격
	# ================================
	if (
		Input.is_action_just_pressed("attack")
		and has_sword
		and not is_attacking
	):
		attack()


	if not is_attacking and not is_double_jumping:
		update_animation()


	move_and_slide()


# =========================================
# 점프
# =========================================

func try_jump() -> void:
	if not can_move:
		return

	# 첫 번째 점프
	if is_on_floor():
		jump_count = 1
		velocity.y = jump_force

		play_jump_sound()

	# 두 번째 점프
	elif jump_count < max_jump_count:
		jump_count += 1

		velocity.y = jump_force

		is_double_jumping = true

		animated_sprite.play("DubbleJump")

		play_jump_sound()


# =========================================
# 기본 애니메이션
# =========================================

func update_animation() -> void:
	if is_double_jumping:
		return

	if is_on_floor():
		if has_sword:
			animated_sprite.play("Walk_Gum")
		else:
			animated_sprite.play("Walk")

	else:
		if has_sword:
			animated_sprite.play("Jump_Gum")
		else:
			animated_sprite.play("Jump")


# =========================================
# 검 획득
# =========================================

func get_sword() -> void:
	has_sword = true

	sword_time_left = sword_duration

	sword_ui.visible = true

	sword_time_label.visible = true
	sword_time_label.text = "🗡️ %.1fs" % sword_time_left

	show_attack_buff()

	print("검 획득! %.1f초 동안 사용 가능" % sword_duration)


# =========================================
# 검 효과 종료
# =========================================

func end_sword() -> void:
	has_sword = false
	sword_time_left = 0.0

	is_attacking = false
	hit_enemy = false

	attack_area.monitoring = false

	sword_ui.visible = false
	sword_time_label.visible = false

	print("검 효과 종료")


# =========================================
# 공격
# =========================================

func attack() -> void:
	if not has_sword:
		return

	if is_attacking:
		return

	is_attacking = true
	hit_enemy = false

	attack_area.monitoring = true

	if is_on_floor():
		animated_sprite.play("Walk_Gum_Attack")
	else:
		animated_sprite.play("Jump_Gum_Attack")

	await animated_sprite.animation_finished

	if not has_sword:
		attack_area.monitoring = false
		is_attacking = false
		hit_enemy = false
		return

	if hit_enemy:
		await get_tree().create_timer(0.3).timeout

	attack_area.monitoring = false
	is_attacking = false
	hit_enemy = false


# =========================================
# 공격 판정
# =========================================

func _on_attack_area_body_entered(body: Node2D) -> void:
	if not is_attacking:
		return

	if body.has_method("hit"):
		hit_enemy = true
		velocity.x = 0.0

		var game = get_tree().current_scene

		if game.has_method("play_slash_sound"):
			game.play_slash_sound()

		body.hit()


# =========================================
# 모바일 검 버튼
# =========================================

func _on_sword_button_pressed() -> void:
	if has_sword and not is_attacking:
		attack()


# =========================================
# 모바일 점프 버튼
# =========================================

func _on_jump_button_pressed() -> void:
	try_jump()


# =========================================
# 방패 획득
# =========================================

func get_shield() -> void:
	has_shield = true
	guard.visible = true

	shield_count_label.visible = true
	shield_count_label.text = "🛡️ x 1"

	show_shield_buff()

	print("방패 획득! 다음 공격 1회 방어")


# =========================================
# 방패 깨짐
# =========================================

func break_shield() -> void:
	if not has_shield:
		return

	has_shield = false
	guard.visible = false

	shield_count_label.visible = false

	print("방패가 공격을 막았습니다!")


# =========================================
# 하트 획득 효과
# =========================================

func show_heart_effect() -> void:
	heart_fever_label.visible = true
	ten_label.visible = true

	heart_fever_label.modulate.a = 1.0
	ten_label.modulate.a = 1.0

	var heart_start_pos := heart_fever_label.position
	var ten_start_pos := ten_label.position

	var tween = create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		heart_fever_label,
		"position:y",
		heart_start_pos.y - 25.0,
		0.4
	)

	tween.tween_property(
		ten_label,
		"position:y",
		ten_start_pos.y - 25.0,
		0.4
	)

	tween.set_parallel(false)
	tween.tween_interval(1.0)

	tween.set_parallel(true)

	tween.tween_property(
		heart_fever_label,
		"modulate:a",
		0.0,
		0.5
	)

	tween.tween_property(
		ten_label,
		"modulate:a",
		0.0,
		0.5
	)

	await tween.finished

	heart_fever_label.visible = false
	ten_label.visible = false

	heart_fever_label.position = heart_start_pos
	ten_label.position = ten_start_pos

	heart_fever_label.modulate.a = 1.0
	ten_label.modulate.a = 1.0


# =========================================
# 공격 버프 효과
# =========================================

func show_attack_buff() -> void:
	attack_buff_label.visible = true
	attack_buff_label.modulate.a = 1.0

	var start_pos := attack_buff_label.position

	var tween = create_tween()

	tween.tween_property(
		attack_buff_label,
		"position:y",
		start_pos.y - 25.0,
		0.4
	)

	tween.tween_interval(0.8)

	tween.tween_property(
		attack_buff_label,
		"modulate:a",
		0.0,
		0.4
	)

	await tween.finished

	attack_buff_label.visible = false
	attack_buff_label.position = start_pos
	attack_buff_label.modulate.a = 1.0


# =========================================
# 방어 버프 효과
# =========================================

func show_shield_buff() -> void:
	shield_buff_label.visible = true
	shield_buff_label.modulate.a = 1.0

	var start_pos := shield_buff_label.position

	var tween = create_tween()

	tween.tween_property(
		shield_buff_label,
		"position:y",
		start_pos.y - 25.0,
		0.4
	)

	tween.tween_interval(0.8)

	tween.tween_property(
		shield_buff_label,
		"modulate:a",
		0.0,
		0.4
	)

	await tween.finished

	shield_buff_label.visible = false
	shield_buff_label.position = start_pos
	shield_buff_label.modulate.a = 1.0


# =========================================
# 피격 효과 문구
# =========================================

func show_damage_effect(amount: float) -> void:
	damage_text_label.visible = true
	damage_amount_label.visible = true

	damage_text_label.modulate.a = 1.0
	damage_amount_label.modulate.a = 1.0

	damage_text_label.text = "적에게 맞음!"
	damage_amount_label.text = "-%d" % int(amount)

	var text_start_pos := damage_text_label.position
	var amount_start_pos := damage_amount_label.position

	var tween = create_tween()

	# 1. 살짝 위로 올라가기
	tween.set_parallel(true)

	tween.tween_property(
		damage_text_label,
		"position:y",
		text_start_pos.y - 25.0,
		0.35
	)

	tween.tween_property(
		damage_amount_label,
		"position:y",
		amount_start_pos.y - 25.0,
		0.35
	)

	# 2. 잠깐 유지
	tween.set_parallel(false)
	tween.tween_interval(0.7)

	# 3. 천천히 사라짐
	tween.set_parallel(true)

	tween.tween_property(
		damage_text_label,
		"modulate:a",
		0.0,
		0.4
	)

	tween.tween_property(
		damage_amount_label,
		"modulate:a",
		0.0,
		0.4
	)

	await tween.finished

	damage_text_label.visible = false
	damage_amount_label.visible = false

	damage_text_label.position = text_start_pos
	damage_amount_label.position = amount_start_pos

	damage_text_label.modulate.a = 1.0
	damage_amount_label.modulate.a = 1.0


# =========================================
# 점프 효과음
# =========================================

func play_jump_sound() -> void:
	var game = get_tree().current_scene

	if game.has_method("play_jump_sound"):
		game.play_jump_sound()
