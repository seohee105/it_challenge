extends CharacterBody2D
## 보스: '수확 로봇' (설계도 9구간 - 슈가 봇 동장, 보스전)
## 공격 방법 1) 점프해서 위쪽 약점(WeakpointHurtbox) 밟기
## 공격 방법 2) 🗡️ 공격 아이템을 보유한 상태로 몸통에 닿으면 즉시 처치

signal boss_defeated

@export var max_hp: int = 10
@export var speed: float = 40.0
@export var patrol_distance: float = 180.0

const GRAVITY: float = 980.0

var hp: int
var _direction: int = 1
var _start_x: float

@onready var hp_bar: ProgressBar = $HPBar
@onready var weakpoint: Area2D = $WeakpointHurtbox

func _ready() -> void:
	hp = max_hp
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	_start_x = global_position.x
	add_to_group("enemy")
	$Hitbox.add_to_group("enemy_hitbox")
	weakpoint.body_entered.connect(_on_weakpoint_entered)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0
	velocity.x = speed * _direction
	move_and_slide()
	if abs(global_position.x - _start_x) >= patrol_distance:
		_direction *= -1

func _on_weakpoint_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.velocity.y > 0:
		take_damage(1)
		body.velocity.y = -350

func take_damage(amount: int) -> void:
	hp -= amount
	hp_bar.value = hp
	if hp <= 0:
		boss_defeated.emit()
		get_tree().call_deferred("change_scene_to_file", "res://scenes/Victory.tscn")
		call_deferred("queue_free")

func die() -> void:
	take_damage(hp)
