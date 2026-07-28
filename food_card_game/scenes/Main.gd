## BUFF UP! Diet — 보스전 (기획서 기준: 실시간 쿨타임 카드 3종)
##  · 슈가 러시(탄) : 3~5회 연속 타격 · 쿨 6초
##  · 프로틴 샷(단) : 강력한 한 방      · 쿨 8초
##  · 뱃살 쿵(지)   : 피해 70% 감소 방어 · 쿨 12초
##  · 탄/단/지 사용 비율을 45/30/25 에 맞추면 "영양 밸런스" → 쿨타임 감소
extends Control

const PlayerViewScript := preload("res://scenes/PlayerView.gd")
const BossViewScript := preload("res://scenes/BossView.gd")
const FxScript := preload("res://scenes/Fx.gd")
const SfxScript := preload("res://scenes/Sfx.gd")
const ArenaBgScript := preload("res://scenes/ArenaBg.gd")
const PixelsData := preload("res://scenes/Pixels.gd")
const PixelSpriteScene := preload("res://scenes/PixelSprite.gd")
const INK := Color("241b2e")

const PLAYER_MAX_HP := 900

# 카드 정의(레벨 스케일링 공용) — 강화 레벨은 Save 에서 로드
const CardDefs := preload("res://scenes/CardDefs.gd")
const TARGET := { "carb": 0.45, "protein": 0.30, "fat": 0.25 }
const MACRO_KR := { "carb": "탄", "protein": "단", "fat": "지" }

# 보스 3종 (맵 컨셉별) + 고유 공격 패턴
const BOSSES := [
	{ "name": "메가 버거 타이탄", "spr": "burger", "tex": "burger", "hp": 2700, "interval": 2.3, "attacks": [
		{ "kind": "multi",    "name": "감자튀김 발사", "dmg": 58, "hits": 3, "icon": "fries" },
		{ "kind": "aoe",      "name": "콜라 폭발",     "dmg": 250, "icon": "cola" },
		{ "kind": "cooldown", "name": "치즈 공격",     "dmg": 55, "add": 3.5, "icon": "cheese" },
	] },
	{ "name": "슈가 퀸", "spr": "sugar_queen", "tex": "queen", "hp": 2450, "interval": 2.1, "attacks": [
		{ "kind": "hit",   "name": "막대사탕 휘두르기", "dmg": 165, "icon": "lollipop" },
		{ "kind": "aoe",   "name": "케이크 낙하",       "dmg": 235, "icon": "cake", "drop": true },
		{ "kind": "stun",  "name": "도넛 던지기",       "dmg": 105, "stun": 1.7, "icon": "donut" },
		{ "kind": "blind", "name": "생크림 던지기",     "dmg": 70, "icon": "cream" },
	] },
	{ "name": "시저 샐러드 킹", "spr": "salad_king", "tex": "king", "hp": 2900, "interval": 2.3, "attacks": [
		{ "kind": "hit",   "name": "포크 낙하",     "dmg": 175, "icon": "fork", "drop": true },
		{ "kind": "multi", "name": "베이컨 던지기", "dmg": 64, "hits": 3, "icon": "bacon" },
		{ "kind": "slow",  "name": "드레싱 발사",   "dmg": 105, "slow": 3.0, "icon": "dressing" },
	] },
]

var _font: Font
var player := {}
var boss := {}
var arena_bg: Control
var cd := [0.0, 0.0, 0.0]
var clevel := [1, 1, 1]   # 카드 강화 레벨 (Save에서)
var _boss_tex := {}       # 보스 이미지 텍스처
var _atk_tex := {}        # 보스 공격 투사체 이미지
var uses := { "carb": 0, "protein": 0, "fat": 0 }
var balanced := false
var running := false
var _autotest := false
var sfx

# UI
var arena_root: VBoxContainer
var character_view
var boss_view
var boss_name_lbl: Label
var warn_lbl: Label
var p_hp_bar: ProgressBar
var p_hp_lbl: Label
var boss_hp_bar: ProgressBar
var boss_hp_lbl: Label
var balance_lbl: RichTextLabel
var guard_lbl: Label
var log_lbl: RichTextLabel
var fx_layer: Control
var card_ui := []
var overlay: Control

func _ready() -> void:
	_font = _load_korean_font()
	var theme := Theme.new()
	if _font:
		theme.default_font = _font
	theme.default_font_size = 16
	self.theme = theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sv0 := get_node_or_null("/root/Save")
	if sv0:
		clevel = [int(sv0.levels[0]), int(sv0.levels[1]), int(sv0.levels[2])]
	for n in ["burger", "queen", "king"]:
		_boss_tex[n] = _load_tex("res://assets/%s.png" % n)
	for n in ["fries", "cola", "cheese", "lollipop", "cake", "donut", "cream", "fork", "bacon", "dressing"]:
		_atk_tex[n] = _load_tex("res://assets/atk_%s.png" % n)
	_build_ui()
	sfx = SfxScript.new()
	add_child(sfx)
	var mus := get_node_or_null("/root/Music")
	if mus:
		mus.play_battle()
	_autotest = OS.get_cmdline_user_args().has("--autotest")
	start_battle()
	if _autotest:
		_run_autotest.call_deferred()

# ────────────────────────────── 폰트
func _load_korean_font() -> Font:
	var gp := ProjectSettings.globalize_path("res://fonts/Galmuri11.ttf")
	if FileAccess.file_exists(gp):
		var ff := FontFile.new()
		if ff.load_dynamic_font(gp) == OK:
			_pixelize(ff)
			return ff
	if ResourceLoader.exists("res://fonts/Galmuri11.ttf"):
		var f = load("res://fonts/Galmuri11.ttf")
		if f is FontFile:
			_pixelize(f)
			return f
	for path in [ProjectSettings.globalize_path("res://fonts/malgun.ttf"), "C:/Windows/Fonts/malgun.ttf"]:
		if FileAccess.file_exists(path):
			var mf := FontFile.new()
			if mf.load_dynamic_font(path) == OK:
				return mf
	return ThemeDB.fallback_font

func _pixelize(ff: FontFile) -> void:
	ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	ff.hinting = TextServer.HINTING_NONE
	ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	ff.force_autohinter = false

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t = load(path)
		if t is Texture2D:
			return t
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(path)) == OK:
		return ImageTexture.create_from_image(img)
	return null

# ────────────────────────────── UI
func _build_ui() -> void:
	arena_bg = ArenaBgScript.new()
	arena_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arena_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(arena_bg)

	var root := VBoxContainer.new()
	arena_root = root
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 12
	root.offset_bottom = -12
	add_child(root)

	# 아레나: 캐릭터(좌) vs 보스(우)
	var arena := HBoxContainer.new()
	arena.add_theme_constant_override("separation", 10)
	root.add_child(arena)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	arena.add_child(left)
	var lspace := Control.new()
	lspace.custom_minimum_size = Vector2(0, 30)
	left.add_child(lspace)
	character_view = PlayerViewScript.new()
	left.add_child(_center_wrap(character_view))
	left.add_child(_title_label("나", Color("8fd1ff")))
	var p_row := HBoxContainer.new()
	p_row.alignment = BoxContainer.ALIGNMENT_CENTER
	p_row.add_theme_constant_override("separation", 8)
	left.add_child(p_row)
	p_hp_bar = _make_bar(PLAYER_MAX_HP, Color("6bbf59"))
	p_hp_bar.custom_minimum_size = Vector2(280, 22)
	p_row.add_child(p_hp_bar)
	p_hp_lbl = _stat_label(Color.WHITE, 17, 110)
	p_row.add_child(p_hp_lbl)
	guard_lbl = _stat_label(Color("8ce39b"), 16, 0)
	guard_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(guard_lbl)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	arena.add_child(right)
	warn_lbl = _title_label("", Color("ff8f6b"))
	warn_lbl.custom_minimum_size = Vector2(0, 30)
	right.add_child(warn_lbl)
	boss_view = BossViewScript.new()
	right.add_child(_center_wrap(boss_view))
	boss_name_lbl = _title_label("", Color("ffcf6b"))
	right.add_child(boss_name_lbl)
	var b_row := HBoxContainer.new()
	b_row.alignment = BoxContainer.ALIGNMENT_CENTER
	b_row.add_theme_constant_override("separation", 8)
	right.add_child(b_row)
	boss_hp_bar = _make_bar(1000, Color("d24b4b"))
	boss_hp_bar.custom_minimum_size = Vector2(300, 22)
	b_row.add_child(boss_hp_bar)
	boss_hp_lbl = _stat_label(Color.WHITE, 17, 130)
	b_row.add_child(boss_hp_lbl)

	# (로그·밸런스 텍스트 표시 안 함) — 가운데 빈 공간
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	# 카드 바 (쿨타임 3종) + 카드 아래 스킬 이름
	var card_wrap := CenterContainer.new()
	card_wrap.custom_minimum_size = Vector2(0, 246)
	root.add_child(card_wrap)
	var card_box := HBoxContainer.new()
	card_box.add_theme_constant_override("separation", 16)
	card_box.alignment = BoxContainer.ALIGNMENT_END
	card_wrap.add_child(card_box)
	card_ui.clear()
	for i in CardDefs.LIST.size():
		var colv := VBoxContainer.new()
		colv.add_theme_constant_override("separation", 4)
		card_box.add_child(colv)
		colv.add_child(_card_widget(i))
		var nml := Label.new()
		nml.text = String(CardDefs.LIST[i].name)
		nml.add_theme_font_size_override("font_size", 18)
		nml.add_theme_color_override("font_color", Color.WHITE)
		nml.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		nml.add_theme_constant_override("outline_size", 6)
		nml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		colv.add_child(nml)

	fx_layer = Control.new()
	fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)

	var mute := Button.new()
	mute.focus_mode = Control.FOCUS_NONE
	mute.add_theme_font_size_override("font_size", 14)
	mute.anchor_left = 1.0
	mute.anchor_right = 1.0
	mute.offset_left = -128
	mute.offset_top = 8
	mute.offset_right = -12
	mute.offset_bottom = 38
	var m0 := get_node_or_null("/root/Music")
	mute.text = "BGM: OFF" if (m0 and m0.muted) else "BGM: ON"
	mute.pressed.connect(func() -> void:
		var m := get_node_or_null("/root/Music")
		if m:
			mute.text = "BGM: OFF" if m.toggle_mute() else "BGM: ON"
	)
	add_child(mute)

func _center_wrap(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.add_child(c)
	return cc

func _title_label(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 21)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _make_bar(maxv: int, col: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = maxv
	bar.value = maxv
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 22)
	var bgsb := StyleBoxFlat.new()
	bgsb.bg_color = Color(0, 0, 0, 0.35)
	bgsb.set_corner_radius_all(0)
	bar.add_theme_stylebox_override("background", bgsb)
	var fillsb := StyleBoxFlat.new()
	fillsb.bg_color = col
	fillsb.set_corner_radius_all(0)
	bar.add_theme_stylebox_override("fill", fillsb)
	return bar

func _stat_label(col: Color, sz: int, min_w: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	if min_w > 0:
		l.custom_minimum_size = Vector2(min_w, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(0)
	sb.border_color = border
	sb.set_border_width_all(bw)
	return sb

func _card_widget(i: int) -> Control:
	var c: Dictionary = CardDefs.LIST[i]
	var col := Color(c.color)
	var root := Control.new()
	root.custom_minimum_size = Vector2(168, 200)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	# 프레임 (다크 테마 배경 + 컬러 테두리 + 드롭 섀도)
	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = col.darkened(0.74)
	fsb.set_corner_radius_all(8)
	fsb.border_color = col
	fsb.set_border_width_all(3)
	fsb.shadow_color = Color(0, 0, 0, 0.45)
	fsb.shadow_size = 7
	fsb.shadow_offset = Vector2(0, 5)
	frame.add_theme_stylebox_override("panel", fsb)
	root.add_child(frame)

	# 상단 컬러 밴드 (헤더)
	var band := Panel.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.anchor_right = 1.0
	band.offset_left = 7; band.offset_top = 7
	band.offset_right = -7; band.offset_bottom = 16
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = col
	bsb.set_corner_radius_all(4)
	band.add_theme_stylebox_override("panel", bsb)
	root.add_child(band)

	# 아이콘 인셋 박스
	var iconbox := Panel.new()
	iconbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	iconbox.anchor_right = 1.0; iconbox.anchor_bottom = 1.0
	iconbox.offset_left = 11; iconbox.offset_top = 22
	iconbox.offset_right = -11; iconbox.offset_bottom = -11
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color("120e1c")
	isb.set_corner_radius_all(5)
	isb.border_color = col.darkened(0.25)
	isb.set_border_width_all(2)
	iconbox.add_theme_stylebox_override("panel", isb)
	root.add_child(iconbox)

	# 아이콘 뒤 글로우 디스크
	var glow := Panel.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.anchor_left = 0.5; glow.anchor_top = 0.5
	glow.anchor_right = 0.5; glow.anchor_bottom = 0.5
	glow.offset_left = -52; glow.offset_top = -52
	glow.offset_right = 52; glow.offset_bottom = 52
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(col.r, col.g, col.b, 0.24)
	gsb.set_corner_radius_all(52)
	glow.add_theme_stylebox_override("panel", gsb)
	iconbox.add_child(glow)

	# 아이콘
	var spr := PixelSpriteScene.new()
	spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	spr.offset_left = 10; spr.offset_top = 10
	spr.offset_right = -10; spr.offset_bottom = -10
	spr.setup(PixelsData.icon(String(c.spr)), PixelsData.PAL)
	iconbox.add_child(spr)

	# 쿨타임: 아래에서 차오르는 방식 (남은 쿨을 위쪽에 어둡게 덮음)
	var fill := ColorRect.new()
	fill.color = Color(0.05, 0.04, 0.08, 0.74)
	fill.anchor_left = 0.0; fill.anchor_right = 1.0
	fill.anchor_top = 0.0; fill.anchor_bottom = 0.0
	fill.offset_left = 4; fill.offset_right = -4; fill.offset_top = 4
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.visible = false
	root.add_child(fill)
	var cdl := Label.new()
	cdl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cdl.add_theme_font_size_override("font_size", 36)
	cdl.add_theme_color_override("font_color", Color.WHITE)
	cdl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	cdl.add_theme_constant_override("outline_size", 6)
	cdl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cdl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cdl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cdl.visible = false
	root.add_child(cdl)

	root.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_use_card(i)
	)
	card_ui.append({ "root": root, "fill": fill, "cd_lbl": cdl, "frame": frame,
		"glow": gsb, "col": col, "max_cd": maxf(0.1, CardDefs.eff_cd(i, clevel[i])) })
	return root

# ────────────────────────────── 전투
func start_battle() -> void:
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
		overlay = null
	var bi: int = randi() % BOSSES.size()
	var b: Dictionary = BOSSES[bi]
	if arena_bg:
		arena_bg.set_boss_theme(bi)
	player = { "hp": PLAYER_MAX_HP, "guard": 0.0, "stun": 0.0, "slow": 0.0 }
	boss = { "name": b.name, "hp": int(b.hp), "max_hp": int(b.hp), "interval": float(b.interval), "timer": 3.2, "attacks": b.attacks, "next": {} }
	boss.next = boss.attacks[randi() % boss.attacks.size()]
	cd = [0.0, 0.0, 0.0]
	uses = { "carb": 0, "protein": 0, "fat": 0 }
	balanced = false
	running = true
	boss_hp_bar.max_value = int(b.hp)
	boss_view.set_sprite(String(b.spr))
	boss_view.set_texture(_boss_tex.get(String(b.get("tex", "")), null))
	boss_view.reset()
	character_view.set_sprite(Save.char_id)   # 저장된 유저 캐릭터 적용 (전환 구조)
	boss_name_lbl.text = b.name
	warn_lbl.text = ""
	_log("[b]%s[/b] 등장! 카드로 물리쳐라!" % b.name)
	_update_hud()
	_recompute_balance()

func _process(delta: float) -> void:
	if not running:
		return
	# 쿨타임 감소 (밸런스 시 가속 / 둔화 시 감속)
	var rate := 1.6 if balanced else 1.0
	if player.slow > 0.0:
		rate *= 0.5
	for i in cd.size():
		if cd[i] > 0.0:
			cd[i] = max(0.0, cd[i] - delta * rate)
	# 상태 타이머
	if player.guard > 0.0:
		player.guard = max(0.0, player.guard - delta)
	if player.stun > 0.0:
		player.stun = max(0.0, player.stun - delta)
	if player.slow > 0.0:
		player.slow = max(0.0, player.slow - delta)
	# 보스 공격 타이머 + 예고
	boss.timer -= delta
	if boss.timer <= 0.7 and boss.timer > 0.0:
		warn_lbl.text = "⚠ %s 준비!" % boss.next.name
	if boss.timer <= 0.0:
		_boss_attack()
		boss.timer = boss.interval
		warn_lbl.text = ""
	_update_cards()
	_update_hud()
	if boss.hp <= 0:
		_end_battle(true)
	elif player.hp <= 0:
		_end_battle(false)

func _use_card(i: int) -> void:
	if not running or cd[i] > 0.0 or player.stun > 0.0:
		return
	var c: Dictionary = CardDefs.LIST[i]
	var lv: int = clevel[i]
	cd[i] = CardDefs.eff_cd(i, lv)
	uses[c.macro] += 1
	_recompute_balance()
	var col := Color(c.color)
	match String(c.kind):
		"multi":
			# 앞으로 돌진 + 주황 연속 슬래시 (3~5회)
			character_view.play_attack()
			sfx_play("shot")
			var hits := randi_range(3, 5)
			var per := CardDefs.eff_dmg(i, lv)
			var total := 0
			var mto := _center(boss_view)
			for h in hits:
				if not running:
					break
				total += per
				boss.hp = max(0, boss.hp - per)
				boss_view.hurt()
				FxScript.burst(fx_layer, mto + Vector2(randf_range(-18, 18), randf_range(-24, 24)), "slash", Color("ffb14a"))
				FxScript.popup(fx_layer, mto + Vector2(80, 20 - h * 30), "-%d" % per, Color("ffd24a"), false)
				_shake(4.0)
				sfx_play("hit")
				await _wait(0.09)
			_log("[color=#f4a7c0]슈가 러시[/color] — %d연타! [b]%d[/b] 데미지" % [hits, total])
		"single":
			# 분홍 에너지 구체 발사
			character_view.play_attack()
			sfx_play("shot")
			await _shoot(_center(character_view), _center(boss_view), Color("ff5ad6"), "energy")
			var d := CardDefs.eff_dmg(i, lv)
			boss.hp = max(0, boss.hp - d)
			boss_view.hurt()
			var sto := _center(boss_view)
			FxScript.burst(fx_layer, sto, "impact", Color("ff5ad6"))
			FxScript.popup(fx_layer, sto, "-%d" % d, Color("ff8ae0"), true)
			_shake(11.0)
			sfx_play("hit")
			_log("[color=#6fa8dc]프로틴 샷[/color] — 강타! [b]%d[/b] 데미지" % d)
		"guard":
			# 캐릭터 주위 초록 방어막 링 (지속시간 동안)
			character_view.play_defense()
			sfx_play("defend")
			player.guard = CardDefs.eff_dur(i, lv)
			var cc := _center(character_view)
			FxScript.aura(fx_layer, cc, Color("6be37a"), player.guard)
			FxScript.popup(fx_layer, cc, "방어!", Color("6be37a"))
			_log("[color=#5bb87a]뱃살 쿵[/color] — %.1f초간 피해 70%% 감소!" % player.guard)

func _boss_attack() -> void:
	var atk: Dictionary = boss.next
	boss.next = boss.attacks[randi() % boss.attacks.size()]   # 다음 공격 예고 갱신
	var kind := String(atk.kind)
	var dmg := int(atk.get("dmg", 0))
	if kind == "multi":
		dmg = int(atk.dmg) * int(atk.hits)
	var pc := _center(character_view)
	# 이름에 맞는 음식 투사체가 날아옴 (낙하 공격은 위에서)
	var icon := String(atk.get("icon", ""))
	if icon != "":
		sfx_play("shot")
		var from := Vector2(pc.x, -40.0) if bool(atk.get("drop", false)) else _center(boss_view)
		await _throw_item(icon, from, pc)
	if not running:
		return
	var guarded: bool = player.guard > 0.0
	if guarded:
		dmg = int(round(dmg * 0.3))
	player.hp = max(0, player.hp - dmg)
	character_view.hurt()
	sfx_play("hurt")
	var burst := "boom" if kind == "aoe" else "impact"
	FxScript.burst(fx_layer, pc, burst, Color("ff8f6b"))
	if dmg > 0:
		FxScript.popup(fx_layer, pc, "-%d" % dmg, Color("ff6b6b"), true)
	_shake(10.0 if kind == "aoe" else 6.0)

	var note := ""
	match kind:
		"cooldown":
			for j in cd.size():
				cd[j] += float(atk.add)
			note = " — 카드 쿨타임 +%.0f초!" % float(atk.add)
			sfx_play("buff")
		"stun":
			player.stun = max(player.stun, float(atk.stun))
			note = " — 기절 %.1f초!" % float(atk.stun)
		"slow":
			player.slow = max(player.slow, float(atk.slow))
			note = " — 쿨타임 둔화!"
		"blind":
			_flash_blind()
			note = " — 시야 차단!"
	if guarded:
		note += "  (방어 70% 감소)"
	_log("[color=#ff9d7a]%s[/color]의 [b]%s[/b]! %d 데미지%s" % [boss.name, atk.name, dmg, note])

func _throw_item(icon: String, from: Vector2, to: Vector2) -> void:
	var node: Control
	var sz := 72.0
	var tex = _atk_tex.get(icon)
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		node = tr
	else:
		var spr := PixelSpriteScene.new()
		spr.setup(PixelsData.icon(icon), PixelsData.PAL)
		node = spr
		sz = 48.0
	node.size = Vector2(sz, sz)
	node.pivot_offset = Vector2(sz * 0.5, sz * 0.5)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.z_index = 95
	fx_layer.add_child(node)
	node.position = from - Vector2(sz * 0.5, sz * 0.5)
	var t := node.create_tween()
	t.set_parallel(true)
	t.tween_property(node, "position", to - Vector2(sz * 0.5, sz * 0.5), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(node, "rotation", TAU, 0.3)
	await t.finished
	node.queue_free()

func _flash_blind() -> void:
	var b := ColorRect.new()
	b.color = Color(1.0, 0.98, 0.9, 0.82)
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(b)
	var t := b.create_tween()
	t.tween_property(b, "color:a", 0.0, 1.2)
	t.tween_callback(b.queue_free)

func _recompute_balance() -> void:
	var total: int = uses.carb + uses.protein + uses.fat
	if total < 3:
		balanced = false
	else:
		var ok := true
		for k in TARGET:
			var r := float(uses[k]) / float(total)
			if abs(r - float(TARGET[k])) > 0.14:
				ok = false
		balanced = ok
	_update_balance_label()

func _update_balance_label() -> void:
	if not balance_lbl:
		return
	var total: int = uses.carb + uses.protein + uses.fat
	var parts := []
	for k in ["carb", "protein", "fat"]:
		var pct := 0
		if total > 0:
			pct = int(round(100.0 * uses[k] / total))
		parts.append("%s %d%%" % [MACRO_KR[k], pct])
	var head := "[color=#ffe082][b]영양 밸런스! 쿨타임 감소 ↑[/b][/color]" if balanced else "[color=#aab4c2]영양 밸런스 (목표 탄45·단30·지25)[/color]"
	balance_lbl.text = "[center]%s    %s[/center]" % [head, "  ·  ".join(parts)]

# ────────────────────────────── 렌더
func _update_cards() -> void:
	for i in card_ui.size():
		var ui: Dictionary = card_ui[i]
		var col: Color = ui.col
		if cd[i] > 0.0:
			var frac: float = clampf(cd[i] / ui.max_cd, 0.0, 1.0)
			ui.fill.visible = true
			ui.fill.anchor_bottom = frac
			ui.cd_lbl.visible = true
			ui.cd_lbl.text = "%.1f" % cd[i]
			ui.root.modulate = Color(0.82, 0.82, 0.86)
			ui.glow.bg_color = Color(col.r, col.g, col.b, 0.12)
		else:
			ui.fill.visible = false
			ui.cd_lbl.visible = false
			ui.root.modulate = Color(1, 1, 1)
			# 준비 완료: 아이콘 글로우 밝게 (은은한 펄스)
			var pulse: float = 0.24 + 0.12 * sin(float(Time.get_ticks_msec()) * 0.005)
			ui.glow.bg_color = Color(col.r, col.g, col.b, pulse)

func _update_hud() -> void:
	p_hp_bar.value = player.hp
	p_hp_lbl.text = "%d / %d" % [player.hp, PLAYER_MAX_HP]
	var ratio := float(player.hp) / float(PLAYER_MAX_HP)
	var fill := p_hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		fill.bg_color = Color("d24b4b") if ratio < 0.3 else (Color("e5a53c") if ratio < 0.6 else Color("6bbf59"))
	boss_hp_bar.value = boss.hp
	boss_hp_lbl.text = "%d / %d" % [boss.hp, boss.max_hp]
	if player.stun > 0.0:
		guard_lbl.text = "기절 %.1f초!" % player.stun
		guard_lbl.add_theme_color_override("font_color", Color("ff8a8a"))
	elif player.guard > 0.0:
		guard_lbl.text = "방어 %.1f초" % player.guard
		guard_lbl.add_theme_color_override("font_color", Color("8ce39b"))
	elif player.slow > 0.0:
		guard_lbl.text = "둔화 %.1f초" % player.slow
		guard_lbl.add_theme_color_override("font_color", Color("caa06a"))
	else:
		guard_lbl.text = ""

func sfx_play(n: String) -> void:
	if sfx:
		sfx.play(n)

func _shoot(from: Vector2, to: Vector2, color: Color, style := "circle") -> void:
	var p := FxScript.make_proj(color, style)
	fx_layer.add_child(p)
	p.position = from
	var t := p.create_tween()
	t.tween_property(p, "position", to, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	p.queue_free()

func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()

func _shake(intensity: float) -> void:
	var base := arena_root.position
	var t := create_tween()
	for i in 4:
		t.tween_property(arena_root, "position", base + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * intensity, 0.04)
	t.tween_property(arena_root, "position", base, 0.05)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _log(bb: String) -> void:
	if log_lbl:
		log_lbl.text = bb

# ────────────────────────────── 종료
func _end_battle(win: bool) -> void:
	if not running:
		return
	running = false
	warn_lbl.text = ""
	var reward: int = CardDefs.CLEAR_COIN if win else CardDefs.TRY_COIN
	var sv := get_node_or_null("/root/Save")
	if sv:
		if win:
			sv.record_win(reward)
		else:
			sv.record_loss(reward)
	if win:
		boss_view.set_defeated()

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(box)

	if win:
		var clear := Label.new()
		clear.text = "CLEAR!"
		clear.add_theme_font_size_override("font_size", 68)
		clear.add_theme_color_override("font_color", Color("ffe082"))
		clear.add_theme_color_override("font_outline_color", INK)
		clear.add_theme_constant_override("outline_size", 8)
		clear.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(clear)
		var sub := Label.new()
		sub.text = "%s 격파!" % boss.name
		sub.add_theme_font_size_override("font_size", 24)
		sub.add_theme_color_override("font_color", Color("cfd8e3"))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sub)
	else:
		var title := Label.new()
		title.text = "GAME OVER"
		title.add_theme_font_size_override("font_size", 52)
		title.add_theme_color_override("font_color", Color("e98a8a"))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)

	var coin_lbl := Label.new()
	coin_lbl.text = "+%d 코인   (보유 %d)" % [reward, (int(sv.coins) if sv else reward)]
	coin_lbl.add_theme_font_size_override("font_size", 20)
	coin_lbl.add_theme_color_override("font_color", Color("ffd45e"))
	coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(coin_lbl)

	var btn := Button.new()
	btn.text = "다시 도전"
	btn.add_theme_font_size_override("font_size", 22)
	btn.custom_minimum_size = Vector2(220, 52)
	btn.pressed.connect(start_battle)
	box.add_child(btn)

	var t_btn := Button.new()
	t_btn.text = "타이틀 · 카드 강화"
	t_btn.add_theme_font_size_override("font_size", 20)
	t_btn.custom_minimum_size = Vector2(220, 46)
	t_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/Title.tscn"))
	box.add_child(t_btn)
	add_child(overlay)

# ────────────────────────────── 개발용 자동 플레이
func _run_autotest() -> void:
	await _wait(0.3)
	var guard := 0
	while running and guard < 400:
		for i in cd.size():
			if cd[i] <= 0.0 and running:
				_use_card(i)
		await _wait(0.15)
		guard += 1
	print("AUTOTEST OK  (player hp=%d, boss hp=%d)" % [player.hp, boss.hp])
	get_tree().quit()
