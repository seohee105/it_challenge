extends Area2D

@export var heal_amount: float = 10.0

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

	# 여러 하트가 서로 다른 타이밍으로 움직이게
	float_time = randf_range(0.0, TAU)


func _process(delta: float) -> void:
	float_time += delta

	# 원래 위치를 중심으로 위아래 이동
	position.y = start_y + sin(
		float_time * float_speed
	) * float_height


func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return

	var game = get_tree().current_scene

	# 하트 회복
	if game.has_method("heal"):
		game.heal(heal_amount)

	# ItemGet 효과음
	if game.has_method("play_item_get_sound"):
		game.play_item_get_sound()
		
	# Heart Fever 전용 효과음
	if game.has_method("play_heart_fever_sound"):
		game.play_heart_fever_sound()
		
	# 하트 획득 문구 효과
	if body.has_method("show_heart_effect"):
		body.show_heart_effect()

	queue_free()
