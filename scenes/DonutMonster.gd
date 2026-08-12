extends CharacterBody2D

@export var move_speed: float = -30.0
@export var gravity: float = 1200.0
@export var damage: float = 15.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var character_collision: CollisionShape2D = $CharacterCollision
@onready var damage_area: Area2D = $DamageArea

var is_dead: bool = false
var already_hit: bool = false


func _ready() -> void:
	# 기본 이동 = 데굴데굴
	animated_sprite.play("Dumbling")

	damage_area.body_entered.connect(_on_damage_area_body_entered)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 중력
	if not is_on_floor():
		velocity.y += gravity * delta

	# 계속 왼쪽으로 이동
	velocity.x = move_speed

	move_and_slide()

	# 맵 아래로 떨어지면 삭제
	if global_position.y > 1400.0:
		queue_free()


# =========================================
# 플레이어와 충돌
# =========================================
func _on_damage_area_body_entered(body: Node2D) -> void:
	if is_dead:
		return

	if already_hit:
		return

	if body.name != "Player":
		return

	already_hit = true

	# =========================================
	# 방패가 있으면
	# =========================================
	if body.has_shield:
		print("도넛이 방패에 부딪힘!")

		body.break_shield()
		
		# Shield 효과음
		var game = get_tree().current_scene

		if game.has_method("play_shield_sound"):
			game.play_shield_sound()
		
		shield_hit()

		return


	# =========================================
	# 방패가 없으면 피해
	# =========================================
	var game = get_tree().current_scene

	if game.has_method("take_damage"):
		game.take_damage(damage)


# =========================================
# 검 공격에 맞았을 때
# Player.gd에서 body.hit() 호출됨
# =========================================
func hit() -> void:
	if is_dead:
		return

	is_dead = true

	print("도넛 몬스터 HURT!")

	# 이동 멈춤
	velocity = Vector2.ZERO

	# 충돌 끄기
	damage_area.set_deferred("monitoring", false)
	character_collision.set_deferred("disabled", true)

	# Hurt 애니메이션
	animated_sprite.play("Hurt")

	# 애니메이션 끝날 때까지 기다림
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
# 방패에 부딪혔을 때
# =========================================
func shield_hit() -> void:
	if is_dead:
		return

	is_dead = true

	print("도넛 몬스터가 방패에 튕겨나감!")

	# 충돌 제거
	damage_area.set_deferred("monitoring", false)
	character_collision.set_deferred("disabled", true)

	# Hurt 애니메이션
	animated_sprite.play("Hurt")

	var start_position := position

	var tween = create_tween()

	# 오른쪽 위로 튕김
	tween.tween_property(
		self,
		"position",
		start_position + Vector2(100.0, -70.0),
		0.22
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 아래로 떨어짐
	tween.tween_property(
		self,
		"position",
		start_position + Vector2(170.0, 30.0),
		0.30
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 동시에 투명해짐
	var fade_tween = create_tween()

	fade_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		0.52
	)

	await tween.finished

	queue_free()
