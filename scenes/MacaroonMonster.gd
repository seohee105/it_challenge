extends CharacterBody2D

@export var move_speed: float = -50.0
@export var gravity: float = 1200.0
@export var damage: float = 15.0


@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var character_collision: CollisionShape2D = $CharacterCollision

@onready var damage_area: Area2D = $DamageArea
@onready var stomp_area: Area2D = $StompArea


var is_dead: bool = false
var is_hurt: bool = false


# =========================================
# 시작
# =========================================

func _ready() -> void:
	# 기본 애니메이션
	animated_sprite.play("Jump")

	# 옆 충돌
	damage_area.body_entered.connect(
		_on_damage_area_body_entered
	)

	# 위에서 밟기
	stomp_area.body_entered.connect(
		_on_stomp_area_body_entered
	)


# =========================================
# 이동
# =========================================

func _physics_process(delta: float) -> void:
	if is_dead or is_hurt:
		return

	# 중력
	if not is_on_floor():
		velocity.y += gravity * delta

	# 왼쪽으로 계속 이동
	velocity.x = move_speed

	move_and_slide()

	# 맵 아래로 떨어지면 삭제
	if global_position.y > 1400.0:
		queue_free()


# =========================================
# 옆에서 플레이어와 충돌
# =========================================

func _on_damage_area_body_entered(body: Node2D) -> void:
	if is_dead or is_hurt:
		return

	if body.name != "Player":
		return


	# =========================================
	# 방패가 있으면 마카롱 튕겨나감
	# =========================================

	if body.has_shield:
		print("마카롱이 방패에 부딪힘!")

		# 플레이어 방패 제거
		body.break_shield()

		# Shield 효과음
		var game = get_tree().current_scene

		if game.has_method("play_shield_sound"):
			game.play_shield_sound()

		# Hurt + 튕겨나감
		shield_hit()

		return


	# =========================================
	# 방패가 없으면 플레이어 피해
	# =========================================

	# 플레이어 잠깐 멈추기
	body.can_move = false
	body.velocity.x = 0.0

	var game = get_tree().current_scene

	if game.has_method("take_damage"):
		game.take_damage(damage)

	# 충돌 순간 잠깐 보여주기
	await get_tree().create_timer(0.35).timeout

	if is_instance_valid(body):
		body.can_move = true


# =========================================
# 플레이어가 위에서 밟았을 때
# =========================================

func _on_stomp_area_body_entered(body: Node2D) -> void:
	if is_dead or is_hurt:
		return

	if body.name != "Player":
		return

	# 내려오는 중일 때만 밟기 인정
	if body.velocity.y <= 0.0:
		return

	stomped(body)


# =========================================
# 밟혀서 사망
# =========================================

func stomped(player: Node2D) -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO

	# =========================================
	# 밟기 효과음
	# =========================================

	var game = get_tree().current_scene

	if game.has_method("play_stomp_sound"):
		game.play_stomp_sound()


	# 추가 피해 판정 끄기
	damage_area.set_deferred(
		"monitoring",
		false
	)

	stomp_area.set_deferred(
		"monitoring",
		false
	)


	# 플레이어를 마카롱 가까이에 위치
	player.global_position.y = global_position.y - 40.0

	# 플레이어 잠깐 정지
	player.can_move = false
	player.velocity = Vector2.ZERO

	# Dead 애니메이션
	animated_sprite.play("Dead")

	# 죽는 모습 보여주기
	await get_tree().create_timer(0.35).timeout


	# 몸 충돌 제거
	character_collision.set_deferred(
		"disabled",
		true
	)


	# 플레이어 다시 이동
	if is_instance_valid(player):
		player.can_move = true


	# Dead 모습 조금 더 보여주기
	await get_tree().create_timer(0.15).timeout

	queue_free()


# =========================================
# 검 공격에 맞았을 때
# =========================================

func hit() -> void:
	if is_dead or is_hurt:
		return

	is_hurt = true
	velocity = Vector2.ZERO


	# 모든 충돌 제거
	damage_area.set_deferred(
		"monitoring",
		false
	)

	stomp_area.set_deferred(
		"monitoring",
		false
	)

	character_collision.set_deferred(
		"disabled",
		true
	)


	# Hurt 애니메이션
	animated_sprite.play("Hurt")

	await animated_sprite.animation_finished


	# 살짝 위로 뜨면서 사라지기
	var tween = create_tween()

	tween.set_parallel(true)


	tween.tween_property(
		self,
		"position:y",
		position.y - 10.0,
		0.25
	)


	tween.tween_property(
		self,
		"modulate:a",
		0.0,
		0.25
	)


	await tween.finished

	queue_free()


# =========================================
# 방패 / Bubble에 닿았을 때
# =========================================

func shield_hit() -> void:
	if is_dead or is_hurt:
		return

	is_hurt = true
	velocity = Vector2.ZERO


	# 충돌 제거
	damage_area.set_deferred(
		"monitoring",
		false
	)

	stomp_area.set_deferred(
		"monitoring",
		false
	)

	character_collision.set_deferred(
		"disabled",
		true
	)


	# Hurt 애니메이션
	animated_sprite.play("Hurt")


	var start_position := position

	var tween = create_tween()


	# 1단계: 오른쪽 위로 튕김
	tween.tween_property(
		self,
		"position",
		start_position + Vector2(90.0, -60.0),
		0.22
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)


	# 2단계: 아래로 떨어짐
	tween.tween_property(
		self,
		"position",
		start_position + Vector2(150.0, 30.0),
		0.30
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN
	)


	# 동시에 점점 투명하게
	var fade_tween = create_tween()

	fade_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		0.52
	)


	await tween.finished

	queue_free()
