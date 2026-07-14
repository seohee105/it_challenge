extends Control

@onready var category_container: VBoxContainer = $VBox/ScrollContainer/CategoryContainer
@onready var back_button: Button = $VBox/BackButton
@onready var msg_label: Label = $VBox/MsgLabel

var selected_custom_category_id: String = ""
var custom_row_controls: Dictionary = {}

func _ready() -> void:
	back_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/Home.tscn")
	)

	for cat in ExerciseData.CATEGORIES:
		_add_category_row(cat)


func _add_category_row(cat: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var btn := Button.new()
	btn.text = cat.name
	btn.custom_minimum_size = Vector2(140, 0)
	row.add_child(btn)

	var line_edit: LineEdit = null
	if cat.is_custom:
		line_edit = LineEdit.new()
		line_edit.placeholder_text = cat.examples
		line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line_edit.visible = false
		row.add_child(line_edit)

		var confirm_button := Button.new()
		confirm_button.text = "확인"
		confirm_button.custom_minimum_size = Vector2(80, 0)
		confirm_button.visible = false
		confirm_button.pressed.connect(_on_confirm_pressed.bind(cat, line_edit))
		row.add_child(confirm_button)

		line_edit.focus_entered.connect(func():
			confirm_button.visible = true
		)

		custom_row_controls[cat.id] = {
			"line_edit": line_edit,
			"confirm_button": confirm_button,
		}

	btn.pressed.connect(_on_category_pressed.bind(cat, line_edit))
	category_container.add_child(row)


func _on_category_pressed(cat: Dictionary, line_edit: LineEdit) -> void:
	if not cat.is_custom:
		_add_home_item_if_valid(cat, "", line_edit)
		return

	if line_edit == null:
		return

	var controls: Dictionary = custom_row_controls.get(cat.id, {})
	var is_visible := line_edit.visible
	line_edit.visible = not is_visible
	var confirm_button: Button = null
	if controls.has("confirm_button"):
		confirm_button = controls["confirm_button"]
	if confirm_button != null:
		confirm_button.visible = not is_visible
	if line_edit.visible:
		line_edit.grab_focus()


func _on_confirm_pressed(cat: Dictionary, line_edit: LineEdit) -> void:
	if not cat.is_custom or line_edit == null:
		return
	var custom_label := line_edit.text.strip_edges()
	if custom_label == "":
		line_edit.placeholder_text = "운동 이름을 입력해주세요"
		line_edit.grab_focus()
		return

	_add_home_item_if_valid(cat, custom_label, line_edit)

	# 클릭 후에도 입력란에서 포커스가 유지되면 확인 버튼을 계속 보이게 함
	line_edit.grab_focus()


func _add_home_item_if_valid(cat: Dictionary, custom_label: String, line_edit: LineEdit) -> void:
	for item in SessionManager.home_items:
		if item.category_id == cat.id:
			if cat.is_custom and item.custom_label == custom_label:
				_show_temp_message("이미 선택한 운동입니다.", 0.5)
				return
			if not cat.is_custom:
				_show_temp_message("이미 선택한 운동입니다.", 0.5)
				return

	SessionManager.add_home_item(cat.id, custom_label)
	get_tree().change_scene_to_file("res://scenes/Home.tscn")


func _show_temp_message(msg: String, dur: float = 0.5) -> void:
	msg_label.text = msg
	msg_label.visible = true
	await get_tree().create_timer(dur).timeout
	msg_label.visible = false
