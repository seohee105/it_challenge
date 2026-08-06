extends Control

func _on_retry_button_pressed() -> void:
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/Level1.tscn")

func _on_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
