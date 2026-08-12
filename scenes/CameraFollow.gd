extends Camera2D

@onready var player: CharacterBody2D = $"../Player"

@export var x_offset: float = 900.0

var fixed_y: float


func _ready() -> void:
	fixed_y = global_position.y


func _physics_process(_delta: float) -> void:
	if player == null:
		return

	# 플레이어보다 카메라를 오른쪽에 두기
	global_position.x = player.global_position.x + x_offset

	# Y축은 고정
	global_position.y = fixed_y
