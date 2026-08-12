extends Control

signal next_pressed

@onready var dialogue_label: Label = $Panel/DialogueLabel
@onready var next_button: Button = $Panel/NextButton

@export var typing_speed: float = 0.09

var is_typing: bool = false


func _ready() -> void:
	next_button.visible = false
	next_button.pressed.connect(_on_next_button_pressed)


# =========================================
# 글자 타이핑
# =========================================

func show_text(text: String) -> void:
	visible = true

	dialogue_label.text = text
	dialogue_label.visible_characters = 0

	next_button.visible = false
	is_typing = true

	for i in range(text.length() + 1):
		dialogue_label.visible_characters = i

		await get_tree().create_timer(
			typing_speed
		).timeout

	is_typing = false

	# 문장이 모두 써지면 >> 표시
	next_button.visible = true


# =========================================
# >> 버튼
# =========================================

func _on_next_button_pressed() -> void:
	if is_typing:
		return

	next_button.visible = false

	next_pressed.emit()
