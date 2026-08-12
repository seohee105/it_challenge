extends Area2D


# =========================================
# 둥둥 뜨는 효과
# =========================================

@export var float_height: float = 10.0
@export var float_speed: float = 2.0

var start_y: float
var float_time: float = 0.0


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
# 공격 아이템 획득
# =========================================

func _on_body_entered(body):

	if body.name != "Player":
		return

	# 아이템 획득 효과음
	body.play_item_get_audio()

	#공격 아이템 활성화
	body.show_attack_button()


	queue_free()
