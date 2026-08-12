extends CharacterBody2D


# =========================================
# 기본 설정
# =========================================

@export var damage: float = 15.0


# =========================================
# 노드
# =========================================

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var character_collision: CollisionShape2D = $CharacterCollision
@onready var damage_area: Area2D = $DamageArea


# =========================================
# 상태
# =========================================

var is_dead: bool = false


# =========================================
# 시작
# =========================================

func _ready() -> void:
	# 처음부터 계속 날고 있음
	animated_sprite.play("Fly")

	damage_area.body_entered.connect(
		_on_damage_area_body_entered
	)


# =========================================
# 플레이어와 몸 충돌
# =========================================

func _on_damage_area_body_entered(body: Node2D) -> void:
	if is_dead:
		return

	if body.name != "Player":
		return


	# 방패가 있을 경우
	if body.has_shield:
		body.break_shield()
		
		var game = get_tree().current_scene
		
		if game.has_method("play_shield_sound"):
			game.play_shield_sound()

		shield_hit()
		return


	# 방패가 없으면 플레이어 데미지
	var game = get_tree().current_scene

	if game.has_method("take_damage"):
		game.take_damage(damage)


# =========================================
# 검 공격
# =========================================

func hit() -> void:
	if is_dead:
		return

	is_dead = true

	velocity = Vector2.ZERO


	# 충돌 제거
	damage_area.set_deferred(
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


	# 살짝 위로 뜨면서 사라짐
	var tween = create_tween()
	tween.set_parallel(true)


	tween.tween_property(
		self,
		"position:y",
		position.y - 12.0,
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
# 방패 / Bubble 충돌
# =========================================

func shield_hit() -> void:
	if is_dead:
		return

	is_dead = true

	velocity = Vector2.ZERO


	# 충돌 제거
	damage_area.set_deferred(
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


	# 오른쪽 위로 튕겨나가기
	tween.tween_property(
		self,
		"position",
		start_position + Vector2(100.0, -70.0),
		0.22
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)


	# 아래쪽으로 떨어지기
	tween.tween_property(
		self,
		"position",
		start_position + Vector2(170.0, 30.0),
		0.30
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN
	)


	# 서서히 사라지기
	var fade_tween = create_tween()

	fade_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		0.52
	)


	await tween.finished

	queue_free()
