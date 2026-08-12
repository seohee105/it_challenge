## 첫화면 (BUFF UP! Diet) — 시작 · 기록/코인 · 조작법 · 카드 강화 · 페이드
extends Control

const CardDefs := preload("res://scenes/boss_battle/CardDefs.gd")
const INK := Color("241b2e")
const MACRO_KR := { "carb": "탄", "protein": "단", "fat": "지" }

var _font: Font
var _fade: ColorRect
var _help: Control
var _up: Control
var _up_rows: VBoxContainer
var _up_coins: Label
var _rec: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = _load_font()
	var theme := Theme.new()
	if _font:
		theme.default_font = _font
	theme.default_font_size = 16
	self.theme = theme

	var mus := get_node_or_null("/root/Music")
	if mus:
		mus.play_title()

	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = _load_tex("res://assets/boss_battle/title_bg.png")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var start := Button.new()
	start.flat = true
	start.focus_mode = Control.FOCUS_NONE
	start.offset_left = 610
	start.offset_top = 635
	start.offset_right = 1055
	start.offset_bottom = 760
	start.pressed.connect(_start_game)
	add_child(start)

	_rec = Label.new()
	_rec.add_theme_font_size_override("font_size", 20)
	_rec.add_theme_color_override("font_color", Color.WHITE)
	_rec.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_rec.add_theme_constant_override("outline_size", 6)
	_rec.anchor_top = 1.0
	_rec.anchor_bottom = 1.0
	_rec.offset_left = 20
	_rec.offset_top = -48
	_rec.offset_bottom = -16
	add_child(_rec)
	_refresh_record()

	# 조작법 + 카드 강화 버튼 (좌상단)
	var help_btn := _corner_btn("조작법", 16, 16, 96)
	help_btn.pressed.connect(func() -> void: _help.visible = not _help.visible)
	add_child(help_btn)
	var up_btn := _corner_btn("카드 강화", 108, 16, 128)
	up_btn.pressed.connect(func() -> void:
		_refresh_upgrade()
		_up.visible = true
	)
	add_child(up_btn)

	# BGM 토글 (우상단)
	var mute := Button.new()
	mute.text = "BGM: ON"
	mute.focus_mode = Control.FOCUS_NONE
	mute.anchor_left = 1.0
	mute.anchor_right = 1.0
	mute.offset_left = -140
	mute.offset_top = 16
	mute.offset_right = -16
	mute.offset_bottom = 52
	if mus and mus.muted:
		mute.text = "BGM: OFF"
	mute.pressed.connect(func() -> void:
		var m := get_node_or_null("/root/Music")
		if m:
			mute.text = "BGM: OFF" if m.toggle_mute() else "BGM: ON"
	)
	add_child(mute)

	_build_help()
	_build_upgrade()

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)

func _corner_btn(text: String, x: int, y: int, w: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.offset_left = x
	b.offset_top = y
	b.offset_right = x + w
	b.offset_bottom = y + 32
	return b

func _refresh_record() -> void:
	var sv := get_node_or_null("/root/BossSave")
	var wins := int(sv.wins) if sv else 0
	var best := int(sv.best_streak) if sv else 0
	var coins := int(sv.coins) if sv else 0
	_rec.text = "누적 승리 %d   ·   최고 연승 %d   ·   코인 %d" % [wins, best, coins]

# ── 조작법 오버레이
func _build_help() -> void:
	_help = Control.new()
	_help.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help.visible = false
	add_child(_help)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_help.visible = false
	)
	_help.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.add_theme_stylebox_override("panel", _paper())
	_help.add_child(panel)
	var lbl := Label.new()
	lbl.add_theme_color_override("font_color", INK)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.text = "[ 조작법 ]\n\n· 카드는 쿨타임이 차면 사용 가능\n· 슈가 러시(연타) / 프로틴 샷(강타) / 뱃살 쿵(방어)\n· 보스의 '다음 공격' 예고를 보고 뱃살 쿵으로 방어!\n· 탄·단·지 비율을 45·30·25에 맞추면 쿨타임 감소\n· 클리어 코인으로 카드를 강화하세요\n\n(화면을 클릭하면 닫힘)"
	panel.add_child(lbl)

# ── 카드 강화 오버레이
func _build_upgrade() -> void:
	_up = Control.new()
	_up.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_up.visible = false
	add_child(_up)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.68)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_up.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.add_theme_stylebox_override("panel", _paper())
	_up.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "카드 강화"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	_up_coins = Label.new()
	_up_coins.add_theme_font_size_override("font_size", 20)
	_up_coins.add_theme_color_override("font_color", Color("b8862a"))
	_up_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_up_coins)
	_up_rows = VBoxContainer.new()
	_up_rows.add_theme_constant_override("separation", 8)
	vb.add_child(_up_rows)
	var close := Button.new()
	close.text = "닫기"
	close.add_theme_font_size_override("font_size", 18)
	close.custom_minimum_size = Vector2(120, 40)
	close.pressed.connect(func() -> void: _up.visible = false)
	var cw := CenterContainer.new()
	cw.add_child(close)
	vb.add_child(cw)

func _refresh_upgrade() -> void:
	var sv := get_node_or_null("/root/BossSave")
	var coins := int(sv.coins) if sv else 0
	_up_coins.text = "보유 코인  %d" % coins
	for ch in _up_rows.get_children():
		ch.queue_free()
	for i in CardDefs.LIST.size():
		_up_rows.add_child(_upgrade_row(i, sv))

func _upgrade_row(i: int, sv) -> Control:
	var c: Dictionary = CardDefs.LIST[i]
	var lv: int = int(sv.levels[i]) if sv else 1
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
	btn.custom_minimum_size = Vector2(150, 44)
	btn.add_theme_font_size_override("font_size", 16)
	if lv >= CardDefs.MAX_LV:
		btn.text = "MAX"
		btn.disabled = true
	else:
		var price := CardDefs.cost(lv)
		btn.text = "강화 %d코인" % price
		btn.disabled = (sv == null or int(sv.coins) < price)
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
	var sv := get_node_or_null("/root/BossSave")
	if sv == null:
		return
	var lv: int = int(sv.levels[i])
	if lv >= CardDefs.MAX_LV:
		return
	if sv.upgrade(i, CardDefs.cost(lv)):
		_refresh_upgrade()
		_refresh_record()

# ── 시작
func _start_game() -> void:
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", 1.0, 0.3)
	await t.finished
	get_tree().change_scene_to_file("res://scenes/boss_battle/BossBattle.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not _help.visible and not _up.visible:
		_start_game()

# ── 헬퍼
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

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t = load(path)
		if t is Texture2D:
			return t
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(path)) == OK:
		return ImageTexture.create_from_image(img)
	return null

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
