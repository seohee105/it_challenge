extends CharacterBody2D
## 일반 몬스터 (토마토/브로콜리/아보카도/청경채 공통 스크립트)
## enemy_type 만 바꿔서 여러 종류 몬스터에 재사용
## 랜덤하게 절반 정도는 계속 순찰만 하고, 나머지 절반은 이따금 멈춰서 ATTACK 애니메이션을 보여준다.

const FRAMES_BY_TYPE := {
	"tomato": preload("res://assets/enemy/tomato/TOMATO_frames.tres"),
	"broccoli": preload("res://assets/enemy/broccoli/BROCCOLI_frames.tres"),
	"avocado": preload("res://assets/enemy/avocado/AVOCADO_frames.tres"),
	"bokchoy": preload("res://assets/enemy/bokchoy/BOKCHOY_frames.tres"),
}
const DEATH_ANIM_DURATION: float = 0.5
const ATTACK_ANIM_DURATION: float = 0.5
const ATTACK_ANIM_MIN_INTERVAL: float = 2.5
const ATTACK_ANIM_MAX_INTERVAL: float = 4.5
const ATTACK_ANIM_CHANCE: float = 0.5 # 이 비율만큼의 적만 공격 애니메이션을 보여준다

@export var speed: float = 60.0
@export var patrol_distance: float = 150.0
@export var enemy_type: String = "tomato" # tomato, broccoli, avocado, bokchoy

const GRAVITY: float = 980.0

@onready var visual: AnimatedSprite2D = $Visual

var _start_x: float
var _direction: int = 1
var _dying: bool = false
var _shows_attack_anim: bool = false
var _showing_attack: bool = false
var _attack_anim_timer: float = 0.0

func _ready() -> void:
	_start_x = global_position.x
	add_to_group("enemy")
	$Hitbox.add_to_group("enemy_hitbox")
	if FRAMES_BY_TYPE.has(enemy_type):
		visual.sprite_frames = FRAMES_BY_TYPE[enemy_type]
	visual.play("WALK")

	_shows_attack_anim = randf() < ATTACK_ANIM_CHANCE
	if _shows_attack_anim:
		_attack_anim_timer = randf_range(ATTACK_ANIM_MIN_INTERVAL, ATTACK_ANIM_MAX_INTERVAL)

func _physics_process(delta: float) -> void:
	if _dying:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	if _showing_attack:
		# 공격 애니메이션을 보여주는 동안은 제자리에 멈춰서 잘 보이게 한다.
		velocity.x = 0
		move_and_slide()
		return

	velocity.x = speed * _direction
	visual.flip_h = _direction < 0
	move_and_slide()

	# 벽/발판 모서리에 막혀서 실제로는 못 움직이고 있으면(정지 버그 방지) 바로 방향을 돌린다.
	if is_on_wall():
		_direction *= -1
	elif abs(global_position.x - _start_x) >= patrol_distance:
		_direction *= -1

	if _shows_attack_anim:
		_attack_anim_timer -= delta
		if _attack_anim_timer <= 0.0:
			_play_attack_anim()

func _play_attack_anim() -> void:
	_showing_attack = true
	visual.play("ATTACK")
	if not is_inside_tree():
		_showing_attack = false
		return
	await get_tree().create_timer(ATTACK_ANIM_DURATION).timeout
	_showing_attack = false
	if not _dying:
		visual.play("WALK")
	_attack_anim_timer = randf_range(ATTACK_ANIM_MIN_INTERVAL, ATTACK_ANIM_MAX_INTERVAL)

func is_dying() -> bool:
	return _dying

func die() -> void:
	if _dying:
		return
	_dying = true
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	$Hitbox.set_deferred("monitoring", false)
	visual.play("DEATH")
	if not is_inside_tree():
		# 씬 전환 도중 죽음 처리가 들어오면 get_tree()가 null일 수 있으니 바로 정리한다.
		call_deferred("queue_free")
		return
	await get_tree().create_timer(DEATH_ANIM_DURATION).timeout
	call_deferred("queue_free")
