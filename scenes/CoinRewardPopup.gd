extends CanvasLayer

## 식단/운동 기록, 오늘의 목표 달성으로 코인을 얻었을 때 뜨는 알림 팝업.
## 보스전 결과창(BossBattle의 클리어/게임오버 다이얼로그)과 같은 흰 이중 테두리
## 카드 스타일을 그대로 재사용하고, 문구와 버튼만 "획득하기"로 바꿔 쓴다.

var _font: Font
var _overlay: Control


func _ready() -> void:
	_font = _load_font()


func show_reward(amount: int, reason: String) -> void:
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

	var title := Label.new()
	title.text = "코인 획득!"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("2f9e44"))
	title.add_theme_color_override("font_outline_color", Color("1c3a24"))
	title.add_theme_constant_override("outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var msg := Label.new()
	msg.text = reason
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", Color("585858"))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(msg)

	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_theme_constant_override("separation", 14)
	box.add_child(crow)
	crow.add_child(_coin_icon(40))
	var amt := Label.new()
	amt.text = "코인 %d개 획득" % amount
	amt.add_theme_font_size_override("font_size", 28)
	amt.add_theme_color_override("font_color", Color("b8862a"))
	crow.add_child(amt)
	crow.add_child(_coin_icon(40))

	var have_lbl := Label.new()
	have_lbl.text = "보유 코인 %d" % BossSave.coins
	have_lbl.add_theme_font_size_override("font_size", 18)
	have_lbl.add_theme_color_override("font_color", Color("9a8a6a"))
	have_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(have_lbl)

	var claim := _make_button("획득하기", Color("7ac74f"), Color("4e8a2f"))
	claim.pressed.connect(func() -> void:
		if is_instance_valid(_overlay):
			_overlay.queue_free()
	)
	var cw := CenterContainer.new()
	cw.add_child(claim)
	box.add_child(cw)


func _coin_icon(sz: int) -> Control:
	var tr := TextureRect.new()
	tr.texture = load("res://assets/boss_battle/coin.png")
	tr.custom_minimum_size = Vector2(sz, sz)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _make_button(text: String, base: Color, dark: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(180, 64)
	b.add_theme_font_size_override("font_size", 28)
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
