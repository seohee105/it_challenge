extends Node2D
## 게이지는 시간제한처럼 동작한다: 초당 1%(100 만점 기준 1.0)씩 저절로 줄어들며,
## 0이 되면 GameManager.take_damage()가 game_over 신호를 보낸다.

const GAUGE_DRAIN_PER_SECOND: float = 1.0

@onready var ground_builder: Node2D = $GroundBuilder

func _ready() -> void:
	GameManager.game_over.connect(_on_game_over)
	_setup_camera_limits()
	_setup_touch_controls()

func _setup_touch_controls() -> void:
	var player := $Player
	var hud := $HUD
	hud.jump_pressed.connect(player.request_jump)
	hud.attack_pressed.connect(player.request_attack)

func _process(delta: float) -> void:
	if GameManager.current_gauge <= 0.0:
		return
	GameManager.take_damage(GAUGE_DRAIN_PER_SECOND * delta)

func _setup_camera_limits() -> void:
	# 카메라가 지면이 생성되지 않은 레벨 시작/끝 바깥쪽(x<0 등)을 비추지 않도록 막는다.
	var camera: Camera2D = $Player/Camera2D
	if camera == null:
		return
	camera.limit_left = int(ground_builder.start_x)
	camera.limit_right = int(ground_builder.start_x + ground_builder.width)

func _on_game_over() -> void:
	# game_over는 물리 콜백(Area2D 충돌 처리) 도중에 발생할 수 있어서,
	# 즉시 change_scene_to_file을 부르면 "물리 콜백 중 CollisionObject 제거" 오류가 난다.
	get_tree().call_deferred("change_scene_to_file", "res://scenes/GameOver.tscn")
