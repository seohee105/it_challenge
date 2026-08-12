extends Control

@onready var ready_label: Label = $ReadyLabel
@onready var game_start_label: Label = $GameStartLabel


func _ready() -> void:
	ready_label.visible = false
	game_start_label.visible = false


func play_start_sequence() -> void:
	visible = true

	# READY
	ready_label.visible = true
	game_start_label.visible = false

	await get_tree().create_timer(2.0).timeout

	# GAME START!
	ready_label.visible = false
	game_start_label.visible = true

	await get_tree().create_timer(1.0).timeout

	# 연출 종료
	game_start_label.visible = false
	visible = false
