extends CharacterBody2D

const RUN_SPEED = 280.0
const JUMP_FORCE = -730.0

# HP
var hp = 100
var is_game_over = false

# 공격
var has_sword = false
var is_attacking = false
var sword_time = 0.0

# 방패
var shield_active = false

var can_move = true

@onready var shield_effect = $ShieldEffect

@onready var life_bar = $"../CanvasLayer/LifeBar"
@onready var attack_button = $"../CanvasLayer/AttackButton"

@onready var sword_pivot = $SwordPivot
@onready var sword = $SwordPivot/Sword
@onready var sword_hitbox = $SwordPivot/SwordHitbox

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready():

	$LifeTimer.start()

	life_bar.max_value = 100
	life_bar.value = hp

	attack_button.hide()
	shield_effect.hide()

	sword.hide()
	sword_hitbox.monitoring = false

	attack_button.pressed.connect(_on_attack_pressed)


func _physics_process(delta):

	# 중력
	if !is_on_floor():
		velocity.y += gravity * delta

	# 자동 달리기
	if can_move:
		velocity.x = RUN_SPEED
	else:
		velocity.x = 0

	# 점프
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_FORCE

	move_and_slide()

	# 낙사
	if global_position.y > 1000:
		game_over()
		
	if has_sword:
		sword_time -= delta

		if sword_time <= 0:
			has_sword = false
			sword.hide()
			attack_button.hide()
			sword_time = 0.0

#==============================
# HP 자동 감소
#==============================

func _on_life_timer_timeout():

	if shield_active:
		return

	hp -= 1

	if hp < 0:
		hp = 0

	life_bar.value = hp

	if hp <= 0:
		game_over()


#==============================
# 칼 획득
#==============================

func show_attack_button():

	has_sword = true

	sword.show()

	attack_button.show()

	print("공격 가능!")

	sword_time += 6.0
	print('남은 공격시간 :', sword_time)

	


#==============================
# 공격
#==============================

func _on_attack_pressed():

	if !has_sword:
		return

	is_attacking = true
	sword_hitbox.monitoring = true

	var start_pos = position

	# 앞으로 살짝 이동
	var move = create_tween()

	move.tween_property(
		self,
		"position",
		start_pos + Vector2(20,0),
		0.08
	)

	move.tween_property(
		self,
		"position",
		start_pos,
		0.08
	)

	# 칼 휘두르기
	sword_pivot.rotation_degrees = -70

	var swing = create_tween()

	swing.tween_property(
		sword_pivot,
		"rotation_degrees",
		70,
		0.15
	)

	await swing.finished

	sword_pivot.rotation_degrees = 0
	
	sword_hitbox.monitoring = false

	is_attacking = false


#==============================
# 방패
#==============================

func activate_shield():

	if shield_active:
		return

	shield_active = true
	
	shield_effect.show()

	print("방패 활성!")

	await get_tree().create_timer(6.0).timeout

	shield_active = false
	shield_effect.hide()

	print("방패 종료")


#==============================
# 게임오버
#==============================

func game_over():

	if is_game_over:
		return

	is_game_over = true

	print("GAME OVER")

	get_tree().change_scene_to_file("res://Scenes/GameOverScene.tscn")


func enter_boss_door(door_pos):

	can_move = false

	attack_button.hide()

	var tween = create_tween()

	# 문 가운데까지 이동
	tween.tween_property(
		self,
		"global_position",
		Vector2(door_pos.x, global_position.y),
		0.8
	)

	await tween.finished

	# 문 안으로 조금 더 들어감
	var tween2 = create_tween()

	tween2.tween_property(
		self,
		"global_position",
		Vector2(door_pos.x + 60, global_position.y),
		0.5
	)

	await tween2.finished
	modulate.a = 0.0
	await get_tree().create_timer(0.6).timeout
	get_tree().change_scene_to_file("res://Scenes/BossScene.tscn")
