extends Control

signal start_finished

@onready var ready_label: Label = $ReadyLabel
@onready var game_start_label: Label = $GameStartLabel


func _ready():

	# =========================================
	# READY
	# =========================================

	ready_label.show()
	game_start_label.hide()


	await get_tree().create_timer(2.0).timeout


	# =========================================
	# GAME START!
	# =========================================

	ready_label.hide()
	game_start_label.show()


	await get_tree().create_timer(1.0).timeout


	# =========================================
	# 시작
	# =========================================

	game_start_label.hide()

	hide()

	start_finished.emit()
