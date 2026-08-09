extends Area2D
## 플랫포머 구간(1~8구간, 0~8400px)의 끝 지점
## 보스전은 제외되어 여기가 곧 클리어 지점. 게이지가 남아있어야 클리어, 0이면 게임 종료

@export var victory_scene_path: String = "res://scenes/Victory.tscn"
@export var gameover_scene_path: String = "res://scenes/GameOver.tscn"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if GameManager.can_enter_boss():
		get_tree().call_deferred("change_scene_to_file", victory_scene_path)
	else:
		get_tree().call_deferred("change_scene_to_file", gameover_scene_path)
