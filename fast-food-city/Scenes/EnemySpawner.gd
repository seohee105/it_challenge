extends Node2D

@export var enemy_scene: PackedScene

@onready var player = $"../Player"

func _ready():
	randomize()

	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.autostart = true
	timer.timeout.connect(spawn_enemy)
	add_child(timer)


func spawn_enemy():

	var enemy = enemy_scene.instantiate()

	enemy.position.x = player.global_position.x + 1000
	enemy.position.y = randf_range(250, 400)

	get_parent().add_child(enemy)
