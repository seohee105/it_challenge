extends Area2D


# =========================================
# 둥둥 뜨는 효과
# =========================================

@export var float_height: float = 10.0
@export var float_speed: float = 2.0


var start_y: float
var float_time: float = 0.0

var collected: bool = false


# =========================================
# 시작
# =========================================

func _ready():

	start_y = position.y

	float_time = randf_range(
		0.0,
		TAU
	)


# =========================================
# 둥둥 뜨기
# =========================================

func _process(delta):

	float_time += delta * float_speed

	position.y = (
		start_y
		+ sin(float_time) * float_height
	)


# =========================================
# 하트 획득
# =========================================

func _on_body_entered(body):

	if collected:
		return


	if body.name != "Player":
		return


	collected = true


	# =========================================
	# 일반 아이템 획득 효과음
	# =========================================

	if body.has_method("play_item_get_audio"):

		body.play_item_get_audio()


	# =========================================
	# HP 회복 시작
	# =========================================

	if body.has_method("heal_with_heart"):

		body.heal_with_heart(10)


	# =========================================
	# 하트 아이템 삭제
	# =========================================

	queue_free()
