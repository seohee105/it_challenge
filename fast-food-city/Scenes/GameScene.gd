extends Node2D


# =========================================
# 노드
# =========================================

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D

@onready var game_start_scene = $CanvasLayer/GameStartScene

@onready var game_over_popup: Control = $CanvasLayer/GameOverPopup

const RETRY_SCENE: String = "res://fast-food-city/Scenes/GameScene.tscn"


# =========================================
# 카메라 설정
# =========================================

const CAMERA_OFFSET_X = 300.0

var camera_fixed_y: float


# =========================================
# 시작
# =========================================

func _ready():

	# =========================================
	# 게임오버 팝업 (디저트 왕국과 동일한 공용 팝업)
	# =========================================

	game_over_popup.visible = false

	if "retry_scene_path" in game_over_popup:
		game_over_popup.retry_scene_path = RETRY_SCENE


	# =========================================
	# Player 시작 대기
	# =========================================

	player.prepare_game_start()


	# =========================================
	# GameStartScene 완료 신호 연결
	# =========================================

	if not game_start_scene.start_finished.is_connected(
		_on_game_start_finished
	):
		game_start_scene.start_finished.connect(
			_on_game_start_finished
		)


	# =========================================
	# 카메라
	# =========================================

	camera.enabled = true


	# 처음 카메라의 Y 위치 저장
	camera_fixed_y = camera.global_position.y


	# 시작부터 플레이어 X 위치에 맞춤
	camera.global_position.x = (
		player.global_position.x
		+ CAMERA_OFFSET_X
	)


# =========================================
# 매 프레임
# =========================================

func _process(_delta):

	if !is_instance_valid(player):
		return


	# =========================================
	# 좌우만 플레이어 추적
	# =========================================

	camera.global_position.x = (
		player.global_position.x
		+ CAMERA_OFFSET_X
	)


	# =========================================
	# 위아래는 고정
	# =========================================

	camera.global_position.y = camera_fixed_y


# =========================================
# READY → GAME START 완료
# =========================================

func _on_game_start_finished():

	print("GAME START!")

	player.start_game()


# =========================================
# Game Over (디저트 왕국과 동일한 공용 팝업 표시)
# =========================================

func show_game_over() -> void:

	if game_over_popup.has_method("show_game_over"):
		game_over_popup.show_game_over()
	else:
		game_over_popup.visible = true
