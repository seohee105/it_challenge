extends Area2D

@export var speed: float = 200.0
@export var damage: float = 10.0

var direction: Vector2 = Vector2.LEFT


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return

	# 방패가 있으면 사탕 공격 막기
	if body.has_shield:
		body.break_shield()
		queue_free()
		return

	var game = get_tree().current_scene

	if game.has_method("take_damage"):
		game.take_damage(damage)

	queue_free()

func _process(_delta: float) -> void:
	if global_position.x < -500.0:
		queue_free()
