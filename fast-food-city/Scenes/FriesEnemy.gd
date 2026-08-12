extends CharacterBody2D


# =========================================
# 이동 설정
# =========================================

@export var move_speed: float = 10.0
@export var gravity: float = 1200.0


# =========================================
# 공격 설정
# =========================================

@export var contact_damage: int = 20


# =========================================
# 낙사 설정
# =========================================

@export var fall_delete_y: float = 1200.0


# =========================================
# 방패 튕김 설정
# =========================================

@export var shield_bounce_x: float = 150.0
@export var shield_bounce_y: float = 90.0


# =========================================
# 상태
# =========================================

var is_hurt: bool = false
var is_dead: bool = false


# =========================================
# 노드
# =========================================

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var body_collision: CollisionShape2D = $BodyCollision

@onready var damage_area: Area2D = $DamageArea

@onready var damage_collision: CollisionShape2D = \
	$DamageArea/DamageCollision


# =========================================
# 시작
# =========================================

func _ready():

	animated_sprite.play("Walk")


	if not damage_area.body_entered.is_connected(
		_on_damage_area_body_entered
	):
		damage_area.body_entered.connect(
			_on_damage_area_body_entered
		)


# =========================================
# 이동
# =========================================

func _physics_process(delta):

	if is_dead:
		return


	# =========================================
	# 낙사
	# =========================================

	if global_position.y > fall_delete_y:

		queue_free()

		return


	# =========================================
	# Hurt / 방패 튕김 중
	# =========================================

	if is_hurt:

		velocity = Vector2.ZERO

		return


	# =========================================
	# 중력
	# =========================================

	if not is_on_floor():

		velocity.y += gravity * delta

	else:

		if velocity.y > 0:

			velocity.y = 0


	# =========================================
	# 왼쪽 이동
	# =========================================

	velocity.x = -move_speed


	move_and_slide()


# =========================================
# 플레이어 접촉
# =========================================

func _on_damage_area_body_entered(body):

	if is_dead or is_hurt:
		return


	if body.name != "Player":
		return


	# =========================================
	# 방패 활성 상태
	# =========================================

	if body.shield_active:
		
		# 방패 충돌 효과음
		if body.has_method("play_shield_hit_audio"):

			body.play_shield_hit_audio()

		#캄튀 튕겨나가기
		shield_bounce()

		return


	# =========================================
	# 일반 충돌
	# =========================================

	body.hp -= contact_damage


	if body.hp < 0:

		body.hp = 0


	body.life_bar.value = body.hp


	print(
		"FriesEnemy 접촉 / Player HP : ",
		body.hp
	)


	if body.hp <= 0:

		body.game_over()


# =========================================
# 검 공격
# =========================================

func take_hit():

	if is_dead or is_hurt:
		return


	print("FriesEnemy가 검에 맞았습니다!")


	hurt()


# =========================================
# 검에 맞았을 때 Hurt
# =========================================

func hurt():

	if is_dead or is_hurt:
		return


	print("Hurt 실행!")


	is_hurt = true

	velocity = Vector2.ZERO


	# =========================================
	# 충돌 비활성화
	# =========================================

	disable_collisions()


	# =========================================
	# Hurt 애니메이션
	# =========================================

	animated_sprite.stop()

	animated_sprite.frame = 0

	animated_sprite.play("Hurt")


	await animated_sprite.animation_finished


	# Hurt 모습 잠깐 유지
	await get_tree().create_timer(
		0.3
	).timeout


	# =========================================
	# 희미하게 사라짐
	# =========================================

	var disappear_tween = create_tween()


	disappear_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		0.6
	)


	await disappear_tween.finished


	is_dead = true

	queue_free()


# =========================================
# 방패에 부딪혔을 때
# =========================================

func shield_bounce():

	if is_dead or is_hurt:
		return


	print("방패에 부딪혀 튕겨나감!")


	is_hurt = true

	velocity = Vector2.ZERO


	# =========================================
	# 충돌 비활성화
	# =========================================

	disable_collisions()


	# =========================================
	# Hurt 애니메이션
	# =========================================

	animated_sprite.stop()

	animated_sprite.frame = 0

	animated_sprite.play("Hurt")


	# =========================================
	# 시작 위치 저장
	# =========================================

	var start_pos: Vector2 = global_position


	# =========================================
	# 튕겨나가면서 동시에 희미해지기
	# =========================================

	var bounce_tween = create_tween()

	bounce_tween.set_parallel(true)


	# 오른쪽으로 튕김
	bounce_tween.tween_property(
		self,
		"global_position:x",
		start_pos.x + shield_bounce_x,
		0.45
	)


	# 위쪽으로 튕김
	bounce_tween.tween_property(
		self,
		"global_position:y",
		start_pos.y - shield_bounce_y,
		0.22
	)


	# 회전
	bounce_tween.tween_property(
		self,
		"rotation_degrees",
		90.0,
		0.45
	)


	# 동시에 점점 투명해짐
	bounce_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		0.45
	)


	await bounce_tween.finished


	# =========================================
	# 완전히 삭제
	# =========================================

	is_dead = true

	queue_free()

# =========================================
# 충돌 비활성화 공통 함수
# =========================================

func disable_collisions():

	damage_area.set_deferred(
		"monitoring",
		false
	)

	damage_area.set_deferred(
		"monitorable",
		false
	)

	damage_collision.set_deferred(
		"disabled",
		true
	)

	body_collision.set_deferred(
		"disabled",
		true
	)
