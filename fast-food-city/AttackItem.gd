extends Area2D

func _on_body_entered(body):

	if body.name != "Player":
		return

	body.show_attack_button()

	queue_free()
