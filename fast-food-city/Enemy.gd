extends Area2D


# =========================
# 플레이어 몸과 충돌
# =========================
func _on_body_entered(body):

	if body.name != "Player":
		return

	# 방패
	if body.shield_active:
		print("방패로 공격 막음!")
		queue_free()
		return
		
	if body.is_attacking:
		print("⚔ 적 처치!")
		queue_free()
		return

	# 일반 충돌
	body.hp -= 20

	if body.hp < 0:
		body.hp = 0

	body.life_bar.value = body.hp

	print("HP :", body.hp)

	if body.hp <= 0:
		body.game_over()
