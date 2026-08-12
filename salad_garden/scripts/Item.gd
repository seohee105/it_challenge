extends Area2D
## 아이템 픽업: 하트(♥️생명력) / 공격(🗡️) / 방어(🛡️)
## 레벨 씬에서 인스턴스마다 item_type 값을 다르게 지정해서 사용

enum ItemType { HEART, ATTACK, SHIELD }

const FRAMES_BY_TYPE := {
	ItemType.HEART: preload("res://assets/tiles2/item/heart.tres"),
	ItemType.ATTACK: preload("res://assets/tiles2/item/sord.tres"),
	ItemType.SHIELD: preload("res://assets/tiles2/item/defend.tres"),
}
const ANIM_BY_TYPE := {
	ItemType.HEART: &"heart",
	ItemType.ATTACK: &"sword",
	ItemType.SHIELD: &"defend",
}

@export var item_type: ItemType = ItemType.HEART

@onready var visual: AnimatedSprite2D = $Visual

func _ready() -> void:
	visual.sprite_frames = FRAMES_BY_TYPE[item_type]
	visual.play(ANIM_BY_TYPE[item_type])
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	match item_type:
		ItemType.HEART:
			GameManager.gain_heart()
		ItemType.ATTACK:
			GameManager.gain_attack()
		ItemType.SHIELD:
			GameManager.gain_shield()
	call_deferred("queue_free")
