extends Area2D

func _on_body_entered(body):

	if body.name != "Player":
		return

	body.activate_shield()

	queue_free()
