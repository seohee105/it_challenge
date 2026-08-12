extends Control

signal dungeon_selected(dungeon_id: String)

@onready var fast_food_button: TextureButton = $Panel/FastFoodButton
@onready var dessert_button: TextureButton = $Panel/DessertButton
@onready var salad_button: TextureButton = $Panel/SaladButton
@onready var close_button: TextureButton = $Panel/CloseButton


func _ready() -> void:
	fast_food_button.pressed.connect(_on_fast_food_button_pressed)
	dessert_button.pressed.connect(_on_dessert_button_pressed)
	salad_button.pressed.connect(_on_salad_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)


func _on_fast_food_button_pressed() -> void:
	dungeon_selected.emit("fast_food")
	visible = false


func _on_dessert_button_pressed() -> void:
	dungeon_selected.emit("dessert")
	visible = false


func _on_salad_button_pressed() -> void:
	dungeon_selected.emit("salad")
	visible = false


func _on_close_button_pressed() -> void:
	visible = false
