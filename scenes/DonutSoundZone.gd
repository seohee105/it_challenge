extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return

	print(name, " Player 진입")

	var game = get_tree().current_scene

	if game.has_method("start_donut_step_sound"):
		game.start_donut_step_sound()


func _on_body_exited(body: Node2D) -> void:
	if body.name != "Player":
		return

	print(name, " Player 이탈")

	var game = get_tree().current_scene

	if game.has_method("stop_donut_step_sound"):
		game.stop_donut_step_sound()
