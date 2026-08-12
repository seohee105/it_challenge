extends Area2D

# ================================
# 둥실둥실 효과 설정
# ================================

@export var float_height: float = 15.0
@export var float_speed: float = 5.0

var start_y: float
var float_time: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# 처음 배치된 Y 위치 저장
	start_y = position.y

	# 여러 아이템이 똑같이 움직이지 않도록 시작 타이밍 랜덤
	float_time = randf_range(0.0, TAU)


func _process(delta: float) -> void:
	float_time += delta

	# 원래 위치를 중심으로 위아래로 둥실둥실
	position.y = start_y + sin(
		float_time * float_speed
	) * float_height


func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return

	var game = get_tree().current_scene

	# 검 획득
	if body.has_method("get_sword"):
		body.get_sword()

	# ItemGet 효과음
	if game.has_method("play_item_get_sound"):
		game.play_item_get_sound()

	queue_free()
