## 보스 뷰 — 이미지 텍스처(분노/패배 프레임) + 화려한 액션(호흡/돌진/잔상/광폭화)
class_name BossView
extends Control

const PixelsData := preload("res://scenes/Pixels.gd")

var _flash := 0.0
var _shake := 0.0
var _defeated := false
var _enraged := false
var _spr := "boss"
var _tex: Texture2D = null
var _tex_enrage: Texture2D = null
var _tex_defeat: Texture2D = null

# 트랜스폼 (발 밑 피벗)
var _ox := 0.0
var _oy := 0.0
var _rot := 0.0
var _scl := Vector2.ONE
var _after := 0.0
var _idle := 0.0
var _breath := 1.0
var _t := 0.0
var _anim: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(350, 325)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	if _defeated:
		return
	_t += delta
	# 대기: 호흡(스케일) + 위아래 흔들 — 분노 시 더 격렬하게
	var sp := 3.1 if _enraged else 1.6
	var amp := 4.5 if _enraged else 2.5
	_idle = sin(_t * sp) * amp
	_breath = 1.0 + sin(_t * sp * 1.25) * (0.055 if _enraged else 0.022)
	queue_redraw()

func _draw() -> void:
	var s := size

	# 상태별 프레임 선택
	var cur: Texture2D = _tex
	if _defeated and _tex_defeat != null:
		cur = _tex_defeat
	elif _enraged and _tex_enrage != null:
		cur = _tex_enrage

	# 전용 프레임 없을 때만 오버레이/틴트
	var tint := Color(1, 1, 1, 1)
	if _defeated and _tex_defeat == null:
		tint = Color(0.5, 0.5, 0.56)
	elif _enraged and _tex_enrage == null:
		tint = Color(1.4, 0.6, 0.5)

	if cur:
		var tw := float(cur.get_width())
		var th := float(cur.get_height())
		var sc: float = min(s.x / tw, s.y / th)
		var dw := tw * sc
		var dh := th * sc
		var oy_base: float = (s.y - dh) * (1.0 if _defeated else 0.5)
		var pivot := Vector2(s.x * 0.5, oy_base + dh)     # 발 밑
		var rel := Rect2(-dw * 0.5, -dh, dw, dh)
		var scl := Vector2(_scl.x, _scl.y * _breath)

		# 잔상 (공격 시 붉은 트레일)
		if _after > 0.01 and not _defeated:
			for i in 3:
				var f: float = 0.4 + 0.2 * i
				var a: float = (0.09 + 0.06 * i) * _after
				draw_set_transform(pivot + Vector2(_ox * f + _shake, _idle), _rot * f, Vector2.ONE.lerp(scl, f))
				draw_texture_rect(cur, rel, false, Color(1.0, 0.42, 0.3, a))

		draw_set_transform(pivot + Vector2(_ox + _shake, _oy + _idle), _rot, scl)
		draw_texture_rect(cur, rel, false, tint)
		if _flash > 0.0:
			draw_texture_rect(cur, rel, false, Color(3.0, 3.0, 3.0, _flash))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_set_transform(Vector2(_shake + _ox, _idle + _oy), 0.0, Vector2.ONE)
		if _enraged:
			draw_rect(Rect2(s.x * 0.06, s.y * 0.04, s.x * 0.88, s.y * 0.92), Color(1.0, 0.28, 0.18, 0.20))
		var rect := Rect2(0, 0, s.x, s.y)
		PixelsData.draw_grid(self, PixelsData.icon(_spr), PixelsData.PAL, rect, tint)
		if _defeated:
			_draw_ko(s)
		if _flash > 0.0:
			PixelsData.draw_grid(self, PixelsData.icon(_spr), PixelsData.PAL, rect, Color(1, 1, 1, 1), Color(1, 1, 1, _flash))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_ko(s: Vector2) -> void:
	var r := s.x * 0.045
	for cx in [s.x * 0.30, s.x * 0.60]:
		var c := Vector2(cx, s.y * 0.38)
		draw_line(c - Vector2(r, r), c + Vector2(r, r), Color.WHITE, 4.0)
		draw_line(c - Vector2(r, -r), c + Vector2(r, -r), Color.WHITE, 4.0)

func _fresh() -> Tween:
	if _anim != null and _anim.is_valid():
		_anim.kill()
	_anim = create_tween()
	return _anim

# ── 공격: 예비(뒤로 웅크림) → 플레이어 쪽(-x)으로 돌진(기울임+스트레치+잔상) → 탄성 복귀
func play_attack() -> void:
	if _defeated:
		return
	_after = 1.0
	var t := _fresh()
	t.tween_method(_b_ox, _ox, 24.0, 0.12).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_method(_b_sx, _scl.x, 1.10, 0.12)
	t.parallel().tween_method(_b_sy, _scl.y, 0.90, 0.12)
	t.parallel().tween_method(_b_rot, _rot, 0.10, 0.12)
	t.tween_method(_b_ox, 24.0, -50.0, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_b_rot, 0.10, -0.18, 0.10)
	t.parallel().tween_method(_b_sx, 1.10, 0.84, 0.10)
	t.parallel().tween_method(_b_sy, 0.90, 1.18, 0.10)
	t.tween_method(_b_ox, -50.0, 0.0, 0.42).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_b_rot, -0.18, 0.0, 0.42).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_b_sx, 0.84, 1.0, 0.42).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_b_sy, 1.18, 1.0, 0.42).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_b_after, 1.0, 0.0, 0.38)

func hurt() -> void:
	var ts := create_tween()
	ts.tween_method(_set_shake, 16.0, 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var tf := create_tween()
	tf.tween_method(_set_flash, 0.75, 0.0, 0.3)

func _set_shake(v: float) -> void:
	_shake = v
	queue_redraw()

func _set_flash(v: float) -> void:
	_flash = v
	queue_redraw()

func set_defeated() -> void:
	_defeated = true
	_ox = 0.0; _rot = 0.0; _scl = Vector2.ONE; _after = 0.0
	queue_redraw()

func set_enraged() -> void:
	_enraged = true
	# 광폭화 진입 임팩트: 확 커졌다 복귀
	var t := _fresh()
	t.tween_method(_b_sx, 1.0, 1.18, 0.12).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_b_sy, 1.0, 1.18, 0.12).set_ease(Tween.EASE_OUT)
	t.tween_method(_b_sx, 1.18, 1.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_b_sy, 1.18, 1.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	queue_redraw()

func set_sprite(name: String) -> void:
	_spr = name
	queue_redraw()

func set_texture(t: Texture2D) -> void:
	_tex = t
	queue_redraw()

func set_state_textures(enrage: Texture2D, defeat: Texture2D) -> void:
	_tex_enrage = enrage
	_tex_defeat = defeat
	queue_redraw()

func reset() -> void:
	_defeated = false
	_enraged = false
	_ox = 0.0; _oy = 0.0; _rot = 0.0; _scl = Vector2.ONE; _after = 0.0
	queue_redraw()

func _b_ox(v: float) -> void: _ox = v; queue_redraw()
func _b_rot(v: float) -> void: _rot = v; queue_redraw()
func _b_sx(v: float) -> void: _scl.x = v; queue_redraw()
func _b_sy(v: float) -> void: _scl.y = v; queue_redraw()
func _b_after(v: float) -> void: _after = v; queue_redraw()
