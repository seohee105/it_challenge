extends Node2D

func _ready() -> void:
	GameManager.game_over.connect(_on_game_over)

func _on_game_over() -> void:
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")
