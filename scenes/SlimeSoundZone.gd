extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return

	var game = get_tree().current_scene

	if game.has_method("start_slime_move_sound"):
		game.start_slime_move_sound()


func _on_body_exited(body: Node2D) -> void:
	if body.name != "Player":
		return

	var game = get_tree().current_scene

	if game.has_method("stop_slime_move_sound"):
		game.stop_slime_move_sound()
