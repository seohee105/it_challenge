extends Control

func _on_retry_button_pressed():

	get_tree().change_scene_to_file("res://Scenes/GameScene.tscn")


func _on_home_button_pressed():

	get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")
