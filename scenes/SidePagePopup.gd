extends Control

# 어떤 기록 화면을 다이어리 페이지 위에 띄울지는 인스턴스마다 다르게 지정한다
# (예: 캘린더 페이지, 식단기록 페이지, 운동기록 페이지).
@export var record_scene_path: String = ""

@onready var book_panel: TextureRect = $BookPanel
@onready var content_holder: Control = $BookPanel/ContentHolder
@onready var close_button: Button = $BookPanel/CloseButton

var _tween: Tween
var _content_instance: Control = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_panel.pivot_offset = Vector2(book_panel.size.x, book_panel.size.y / 2.0)
	close_button.pressed.connect(close_page)


func open_page() -> void:
	_reload_content()

	visible = true
	book_panel.scale = Vector2(0.08, 1.0)
	book_panel.modulate.a = 0.0

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(book_panel, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(book_panel, "modulate:a", 1.0, 0.25)


func close_page() -> void:
	visible = false


# 열 때마다 내용을 새로 띄워서 최신 기록이 반영되도록 한다.
func _reload_content() -> void:
	if _content_instance != null:
		_content_instance.queue_free()
		_content_instance = null

	_content_instance = load(record_scene_path).instantiate()
	_content_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_holder.add_child(_content_instance)
