extends CanvasLayer

## 밤 10시 이전 던전 입장 시도, 코인 부족 등 짧은 안내 메시지를 띄우는 범용 팝업.
## CoinRewardPopup과 같은 흰 이중 테두리 카드 스타일을 재사용한다.

var _font: Font
var _overlay: Control


func _ready() -> void:
	_font = _load_font()


func show_message(title: String, message: String) -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _font:
		var theme := Theme.new()
		theme.default_font = _font
		theme.default_font_size = 16
		_overlay.theme = theme
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var outer := PanelContainer.new()
	var osb := StyleBoxFlat.new()
	osb.bg_color = Color("ffffff")
	osb.set_corner_radius_all(26)
	osb.shadow_color = Color(0, 0, 0, 0.4)
	osb.shadow_size = 12
	osb.set_content_margin_all(6)
	outer.add_theme_stylebox_override("panel", osb)
	center.add_child(outer)

	var panel := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color("f7f3e9")
	psb.set_corner_radius_all(20)
	psb.border_color = Color("bcc8e6")
	psb.set_border_width_all(3)
	psb.set_content_margin_all(36.0)
	panel.add_theme_stylebox_override("panel", psb)
	outer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 30)
	title_lbl.add_theme_color_override("font_color", Color("e46b6b"))
	title_lbl.add_theme_color_override("font_outline_color", Color("3a2f22"))
	title_lbl.add_theme_constant_override("outline_size", 4)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_lbl)

	var msg_lbl := Label.new()
	msg_lbl.text = message
	msg_lbl.add_theme_font_size_override("font_size", 20)
	msg_lbl.add_theme_color_override("font_color", Color("585858"))
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_lbl.custom_minimum_size = Vector2(360, 0)
	box.add_child(msg_lbl)

	var confirm := _make_button("확인", Color("6fa8dc"), Color("3d6d9e"))
	confirm.pressed.connect(func() -> void:
		if is_instance_valid(_overlay):
			_overlay.queue_free()
	)
	var cw := CenterContainer.new()
	cw.add_child(confirm)
	box.add_child(cw)


func _make_button(text: String, base: Color, dark: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(160, 60)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	b.add_theme_constant_override("outline_size", 5)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = base.lightened(0.08) if st == "hover" else base
		sb.set_corner_radius_all(14)
		sb.border_color = dark
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2 if st == "pressed" else 7
		sb.content_margin_top = 6 if st == "pressed" else 2
		b.add_theme_stylebox_override(st, sb)
	return b


func _load_font() -> Font:
	if ResourceLoader.exists("res://Limgul13.ttf"):
		var f = load("res://Limgul13.ttf")
		if f is Font:
			return f
	return ThemeDB.fallback_font
