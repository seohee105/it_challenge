extends Control

func _on_button_pressed():
	print("메인 버튼 눌림!")
	get_tree().change_scene_to_file("res://scenes/LoginScene.tscn")
