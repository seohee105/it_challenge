extends CanvasLayer

## 오늘의 목표 카드 아래 "카드 강화" 버튼으로 여는 상점. 보스전(BossBattle)에서
## 쓰는 3종 공격 카드를 BossSave에 쌓인 코인으로 강화한다. BossTitle.gd의 카드
## 강화 로직을 그대로 가져와 독립 팝업으로 재구성했다.

const CardDefs := preload("res://scenes/boss_battle/CardDefs.gd")
const INK := Color("241b2e")

var _font: Font
var _overlay: Control
var _coins_label: Label
var _rows_box: VBoxContainer


func _ready() -> void:
	_font = _load_font()


func open_shop() -> void:
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
	dim.color = Color(0, 0, 0, 0.68)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _paper())
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "카드 강화"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 20)
	_coins_label.add_theme_color_override("font_color", Color("b8862a"))
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_coins_label)

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 8)
	vb.add_child(_rows_box)

	var close := Button.new()
	close.text = "메인홈으로"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 18)
	close.custom_minimum_size = Vector2(160, 44)
	close.pressed.connect(func() -> void:
		if is_instance_valid(_overlay):
			_overlay.queue_free()
	)
	var cw := CenterContainer.new()
	cw.add_child(close)
	vb.add_child(cw)

	_refresh()


func _refresh() -> void:
	_coins_label.text = "보유 코인  %d" % BossSave.coins
	for ch in _rows_box.get_children():
		ch.queue_free()
	for i in CardDefs.LIST.size():
		_rows_box.add_child(_upgrade_row(i))


func _upgrade_row(i: int) -> Control:
	var c: Dictionary = CardDefs.LIST[i]
	var lv: int = int(BossSave.levels[i])
	var col := Color(c.color)

	var row := PanelContainer.new()
	var rsb := _box(Color("2b2440"), col, 2)
	rsb.set_content_margin_all(8)
	row.add_theme_stylebox_override("panel", rsb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	row.add_child(hb)

	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(320, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info)
	var nm := Label.new()
	nm.text = "%s   Lv.%d" % [c.name, lv]
	nm.add_theme_font_size_override("font_size", 20)
	nm.add_theme_color_override("font_color", Color.WHITE)
	info.add_child(nm)
	var stat := Label.new()
	stat.add_theme_font_size_override("font_size", 15)
	stat.add_theme_color_override("font_color", Color("cbd3df"))
	stat.text = _summary(i, lv)
	info.add_child(stat)

	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(150, 44)
	btn.add_theme_font_size_override("font_size", 16)
	if lv >= CardDefs.MAX_LV:
		btn.text = "MAX"
		btn.disabled = true
	else:
		var price := CardDefs.cost(lv)
		btn.text = "강화 %d코인" % price
		btn.disabled = BossSave.coins < price
		btn.pressed.connect(func() -> void: _do_upgrade(i))
	hb.add_child(btn)
	return row


func _summary(i: int, lv: int) -> String:
	var c: Dictionary = CardDefs.LIST[i]
	var cur := ""
	var nxt := ""
	if String(c.kind) == "guard":
		cur = "지속 %.1f초 · 쿨 %.1f초" % [CardDefs.eff_dur(i, lv), CardDefs.eff_cd(i, lv)]
		if lv < CardDefs.MAX_LV:
			nxt = "  →  지속 %.1f초 · 쿨 %.1f초" % [CardDefs.eff_dur(i, lv + 1), CardDefs.eff_cd(i, lv + 1)]
	else:
		cur = "공격력 %d · 쿨 %.1f초" % [CardDefs.eff_dmg(i, lv), CardDefs.eff_cd(i, lv)]
		if lv < CardDefs.MAX_LV:
			nxt = "  →  공격력 %d · 쿨 %.1f초" % [CardDefs.eff_dmg(i, lv + 1), CardDefs.eff_cd(i, lv + 1)]
	return cur + nxt


func _do_upgrade(i: int) -> void:
	var lv: int = int(BossSave.levels[i])
	if lv >= CardDefs.MAX_LV:
		return
	if BossSave.upgrade(i, CardDefs.cost(lv)):
		_refresh()


func _paper() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fdf3dd")
	sb.set_corner_radius_all(0)
	sb.border_color = INK
	sb.set_border_width_all(4)
	sb.set_content_margin_all(24)
	return sb


func _box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(0)
	sb.border_color = border
	sb.set_border_width_all(bw)
	return sb


func _load_font() -> Font:
	var gp := ProjectSettings.globalize_path("res://fonts/Galmuri11.ttf")
	if FileAccess.file_exists(gp):
		var ff := FontFile.new()
		if ff.load_dynamic_font(gp) == OK:
			ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			ff.hinting = TextServer.HINTING_NONE
			return ff
	if ResourceLoader.exists("res://fonts/Galmuri11.ttf"):
		var f = load("res://fonts/Galmuri11.ttf")
		if f is Font:
			return f
	return ThemeDB.fallback_font
