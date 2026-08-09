extends Area2D

func _on_body_entered(body):

	if body.name == "Player":

		body.hp += 10

		if body.hp > 100:
			body.hp = 100

		body.life_bar.value = body.hp

		queue_free()
