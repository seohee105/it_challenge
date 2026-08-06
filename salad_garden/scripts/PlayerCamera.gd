extends Camera2D
## 카메라는 가로(X)로만 플레이어를 따라가고, 세로(Y)는 완전히 고정한다.
## 발판이 지면보다 훨씬 높아졌고 점프 높이도 그만큼 커져서, 세로까지 플레이어를 따라가면
## 발판 위에서 다시 최대 높이로 점프했을 때 지면의 적이나 플레이어 자신이 화면 밖으로
## 나가버릴 수 있다. 그래서 세로는 지면과 발판 점프 정점을 모두 담는 고정값으로 못박고,
## 내장 position_smoothing은 세로까지 따라가므로 끄고 가로 추적을 직접 구현한다.

const FIXED_WORLD_Y: float = 294.0
const HORIZONTAL_SMOOTHING_SPEED: float = 8.0

func _ready() -> void:
	var parent := get_parent() as Node2D
	if parent:
		global_position = Vector2(parent.global_position.x, FIXED_WORLD_Y)

func _process(delta: float) -> void:
	var parent := get_parent() as Node2D
	if parent == null:
		return
	var t: float = 1.0 - exp(-HORIZONTAL_SMOOTHING_SPEED * delta)
	var new_x: float = lerp(global_position.x, parent.global_position.x, t)
	global_position = Vector2(new_x, FIXED_WORLD_Y)
