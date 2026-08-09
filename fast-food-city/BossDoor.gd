extends Area2D

var entered = false

func _on_body_entered(body):

	if entered:
		return

	if body.name != "Player":
		return

	entered = true

	body.enter_boss_door(global_position)
