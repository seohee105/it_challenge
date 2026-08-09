extends CharacterBody2D
## 오토런(쿠키런 스타일) 컨트롤러: 앞으로는 항상 자동으로 전진하고,
## 플레이어는 점프와 공격만 조작한다.
## 조작: 점프 - Space/위쪽 화살표 또는 화면 우측 하단 점프 버튼
##       공격 - X키 또는 화면 좌측 하단 공격 버튼 (공격 아이템을 먹은 횟수만큼만 사용 가능, 남은 횟수가 없으면 버튼을 눌러도 공격 안 됨)
## 적과 부딪히면 (공격 버튼을 눌러 처치한 적은 예외 -> 게이지/방어막 소모 없음):
##   - 방어막 보유중 -> 방어막 1개 소모하고 피해 없이 통과
##   - 방어막이 없으면 -> 게이지 감소 + 잠깐 무적
## 지면에 있을 때는 walk, 공중에 떠 있을 때(점프 중)는 run 애니메이션을 사용한다.
## 점프 높이는 두 종류: 평상시엔 낮은 점프만 하고, 아래 두 경우에만 높은 점프를 쓴다.
##   1) 지면에서 발판에 막 올라타야 하는 구간 (LevelBuilder가 미리 계산해 심어둔
##      "platform_trigger" 구역, PlatformSense로 감지) - 발판까지의 거리/타이밍을
##      물리 계산으로 맞춰뒀기 때문에 그 구역 안에서 뛰면 항상 발판에 올라탈 수 있다.
##   2) 이미 발판(그룹 "platform_surface") 위에 서 있을 때 - 다음 발판으로 건너뛸 때
##      필요한 더 먼 도약 거리를 확보하기 위해서다 (평지 위 낮은 점프보다 체공 시간이 길다).

const FORWARD_SPEED: float = 169.4  # 기존 154에서 1.1배 증가 (154 * 1.1)
const JUMP_VELOCITY_HIGH: float = -720.0 # 최대 점프 높이 약 265px. 발판에 올라타야 할 때만 사용.
const JUMP_VELOCITY_LOW: float = -500.0  # 평상시 점프 높이 약 128px. 상자/파이프/아이템은 이걸로 충분.
const GRAVITY: float = 980.0
const ATTACK_ANIM_DURATION: float = 0.2
const ATTACK_RANGE: float = 90.0
## 검(공격 아이템)으로 적을 처치하면, 그 적이 순찰하던 구간(patrol_distance)만큼의 거리 동안
## 전진 속도가 빨라진다 - 적이 있던 위험 구간을 빠르게 통과하라는 보상.
const SWORD_KILL_SPEED_MULTIPLIER: float = 1.8

@onready var visual: AnimatedSprite2D = $Visual
@onready var hurtbox: Area2D = $Hurtbox
@onready var platform_sense: Area2D = $PlatformSense

var invincible: bool = false
var _attacking: bool = false
var _jump_requested: bool = false
var _attack_requested: bool = false
var _platform_trigger_count: int = 0
var _on_elevated_platform: bool = false
var _sword_boost_distance_left: float = 0.0

func _ready() -> void:
	add_to_group("player")
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	platform_sense.area_entered.connect(_on_platform_trigger_area_entered)
	platform_sense.area_exited.connect(_on_platform_trigger_area_exited)
	visual.flip_h = false

## 화면 하단 점프 버튼(HUD)에서 호출
func request_jump() -> void:
	_jump_requested = true

## 화면 하단 공격 버튼(HUD)에서 호출
func request_attack() -> void:
	_attack_requested = true

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif velocity.y > 0:
		velocity.y = 0

	_update_elevated_platform_state()

	var jump_pressed := Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_UP) or _jump_requested
	_jump_requested = false
	if jump_pressed and is_on_floor():
		var use_high_jump: bool = _platform_trigger_count > 0 or _on_elevated_platform
		velocity.y = JUMP_VELOCITY_HIGH if use_high_jump else JUMP_VELOCITY_LOW

	if _attack_requested or Input.is_key_pressed(KEY_X):
		_attack_requested = false
		_try_attack()

	# 오토런: 좌우 조작 없이 항상 앞으로 자동 전진한다.
	# 검으로 적을 처치한 직후에는 그 적의 순찰 거리만큼 더 빠르게 전진한다.
	var forward_speed: float = FORWARD_SPEED
	if _sword_boost_distance_left > 0.0:
		forward_speed = FORWARD_SPEED * SWORD_KILL_SPEED_MULTIPLIER
	velocity.x = forward_speed

	_update_animation()

	move_and_slide()

	if _sword_boost_distance_left > 0.0:
		_sword_boost_distance_left = max(_sword_boost_distance_left - forward_speed * delta, 0.0)

	# 낙사 방지용 리스폰 (필요 시 레벨에서 조정)
	if global_position.y > 2000:
		GameManager.take_damage(GameManager.max_gauge)

## 직전 move_and_slide() 결과를 보고, 지금 밟고 있는 바닥이 발판(그룹 "platform_surface")인지
## 판단한다. 발판 위에서는 다음 발판으로 건너뛰어야 할 수 있으므로 높은 점프를 허용한다.
func _update_elevated_platform_state() -> void:
	_on_elevated_platform = false
	if not is_on_floor():
		return
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider is Node and (collider as Node).is_in_group("platform_surface"):
			_on_elevated_platform = true
			return

func _on_platform_trigger_area_entered(area: Area2D) -> void:
	if area.is_in_group("platform_trigger"):
		_platform_trigger_count += 1

func _on_platform_trigger_area_exited(area: Area2D) -> void:
	if area.is_in_group("platform_trigger"):
		_platform_trigger_count = max(_platform_trigger_count - 1, 0)

func _try_attack() -> void:
	if _attacking:
		return
	if not GameManager.use_attack():
		return
	_play_attack_anim()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or not enemy.has_method("die"):
			continue
		var dx: float = enemy.global_position.x - global_position.x
		if dx >= 0.0 and dx <= ATTACK_RANGE:
			_sword_boost_distance_left += enemy.patrol_distance
			enemy.die()

func _play_attack_anim() -> void:
	_attacking = true
	visual.play("attack")
	if not is_inside_tree():
		_attacking = false
		return
	await get_tree().create_timer(ATTACK_ANIM_DURATION).timeout
	_attacking = false

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if invincible:
		return
	if not area.is_in_group("enemy_hitbox"):
		return
	var enemy: Node = area.get_parent()
	if enemy != null and enemy.has_method("is_dying") and enemy.is_dying():
		# 같은 프레임에 공격으로 처치된 적이면 충돌 페널티(게이지/방어막)를 주지 않는다.
		return

	if GameManager.use_shield():
		_flash_invincible(0.5)
	else:
		GameManager.take_damage()
		_flash_invincible(1.0)

func _flash_invincible(duration: float) -> void:
	invincible = true
	modulate.a = 0.5
	if not is_inside_tree():
		# 씬 전환 도중(예: 레벨 종료로 이 노드가 트리에서 빠지는 순간) 마지막 히트 신호가
		# 뒤늦게 들어오면 get_tree()가 null이 되어 create_timer 호출이 죽는 문제 방지.
		invincible = false
		modulate.a = 1.0
		return
	await get_tree().create_timer(duration).timeout
	invincible = false
	modulate.a = 1.0

func _update_animation() -> void:
	if _attacking:
		return
	var target_anim: StringName = &"walk" if is_on_floor() else &"run"
	if visual.animation != target_anim or not visual.is_playing():
		visual.play(target_anim)
