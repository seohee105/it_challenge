extends Area2D


var collected: bool = false


# =========================================
# 둥둥 뜨는 효과
# =========================================

@export var float_height: float = 10.0
@export var float_speed: float = 2.0

var start_y: float
var float_time: float = 0.0


func _ready():

	# 처음 배치된 Y 위치 저장
	start_y = position.y

	# 여러 아이템이 동시에 똑같이 움직이지 않도록
	# 시작 타이밍 랜덤
	float_time = randf_range(0.0, TAU)


	if not body_entered.is_connected(_on_body_entered):

		body_entered.connect(_on_body_entered)


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
# 아이템 획득
# =========================================

func _on_body_entered(body):

	if collected:
		return


	if body.name != "Player":
		return


	collected = true


	print("방패 아이템 획득!")

	# 아이템 획득 효과음
	body.play_item_get_audio()

	# Player의 방패 기능 실행
	if body.has_method("activate_shield"):

		print("activate_shield 실행!")

		body.activate_shield()

	else:

		print(
			"ERROR : Player에 activate_shield 함수가 없습니다."
		)


	queue_free()
