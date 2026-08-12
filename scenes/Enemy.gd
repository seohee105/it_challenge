extends CharacterBody2D

@export var damage: float = 15.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var damage_area: Area2D = $DamageArea
@onready var body_collision: CollisionShape2D = $BodyCollision

var already_hit: bool = false
var is_dead: bool = false


func _ready() -> void:
	print("슬라임 Enemy.gd 실행됨")

	animated_sprite.play("WALK")
	damage_area.body_entered.connect(_on_damage_area_body_entered)


# ==========================================
# 플레이어가 슬라임 몸에 닿았을 때
# ==========================================
func _on_damage_area_body_entered(body: Node2D) -> void:
	print("DamageArea에 들어온 노드: ", body.name)

	# 이미 죽는 중이면 아무것도 하지 않음
	if is_dead:
		return

	# 이미 한 번 플레이어와 충돌했다면 중복 처리 방지
	if already_hit:
		return

	if body.name != "Player":
		return

	print("Player 감지 성공!")

	already_hit = true

	var game = get_tree().current_scene

	# ==========================================
	# 방패가 있을 때
	# ==========================================
	if body.has_shield:
		print("방패가 슬라임 공격을 막음!")

		# 플레이어 방패 제거
		body.break_shield()
		
		# Shield 효과음
		if game.has_method("play_shield_sound"):
			game.play_shield_sound()
			
		# 슬라임을 튕겨냄
		shield_hit()

		return

	# ==========================================
	# 방패가 없을 때
	# ==========================================
	if game.has_method("take_damage"):
		print("take_damage 호출!")
		game.take_damage(damage)
	else:
		print("ERROR: DessertKingdom에 take_damage가 없음")


# ==========================================
# 검 공격으로 죽을 때
# ==========================================
func hit() -> void:
	if is_dead:
		return

	is_dead = true

	print("슬라임 HURT!")

	# 충돌 제거
	damage_area.set_deferred("monitoring", false)
	body_collision.set_deferred("disabled", true)

	# HURT 애니메이션
	animated_sprite.play("HURT")

	await animated_sprite.animation_finished

	# 살짝 위로 뜨면서 사라짐
	var tween = create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		self,
		"position:y",
		position.y - 8.0,
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


# ==========================================
# 방패에 부딪혔을 때
# ==========================================
func shield_hit() -> void:
	if is_dead:
		return

	is_dead = true

	print("슬라임이 방패에 튕겨나감!")

	# 충돌 제거
	damage_area.set_deferred("monitoring", false)
	body_collision.set_deferred("disabled", true)

	# HURT 애니메이션
	animated_sprite.play("HURT")

	# 방패에 닿는 순간 바로 튕겨나가기
	var start_position := position

	var tween = create_tween()

	# 1단계: 오른쪽 위로 튕김
	tween.tween_property(
		self,
		"position",
		start_position + Vector2(70.0, -45.0),
		0.22
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 2단계: 조금 아래로 떨어짐
	tween.tween_property(
		self,
		"position",
		start_position + Vector2(120.0, 10.0),
		0.28
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 동시에 점점 투명해짐
	var fade_tween = create_tween()

	fade_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		0.5
	)

	await tween.finished

	queue_free()
