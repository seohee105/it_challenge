## 보스 뷰 — 이미지 텍스처(있으면) 또는 도트 스프라이트 렌더 (흔들림/번쩍임/광폭화/처치)
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
var _idle := 0.0
var _t := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(350, 325)

func _process(delta: float) -> void:
	if _defeated:
		return
	_t += delta
	_idle = sin(_t * 1.6) * 2.5
	queue_redraw()

func _draw() -> void:
	var s := size
	draw_set_transform(Vector2(_shake, _idle), 0.0, Vector2.ONE)

	# 상태별 프레임 선택 (분노/패배 전용 이미지가 있으면 그것을 표시)
	var cur: Texture2D = _tex
	if _defeated and _tex_defeat != null:
		cur = _tex_defeat
	elif _enraged and _tex_enrage != null:
		cur = _tex_enrage

	# 전용 프레임이 없을 때만 오버레이/틴트로 상태 표현
	if _enraged and _tex_enrage == null:
		draw_rect(Rect2(s.x * 0.06, s.y * 0.04, s.x * 0.88, s.y * 0.92), Color(1.0, 0.28, 0.18, 0.20))
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
		var oy: float = (s.y - dh) * (1.0 if _defeated else 0.5)   # 패배는 바닥 정렬
		var r := Rect2((s.x - dw) * 0.5, oy, dw, dh)
		draw_texture_rect(cur, r, false, tint)
		if _flash > 0.0:
			draw_texture_rect(cur, r, false, Color(3.0, 3.0, 3.0, _flash))
	else:
		var rect := Rect2(0, 0, s.x, s.y)
		PixelsData.draw_grid(self, PixelsData.icon(_spr), PixelsData.PAL, rect, tint)
		if _defeated:
			_draw_ko(s)
		if _flash > 0.0:
			PixelsData.draw_grid(self, PixelsData.icon(_spr), PixelsData.PAL, rect, Color(1, 1, 1, 1), Color(1, 1, 1, _flash))

func _draw_ko(s: Vector2) -> void:
	var r := s.x * 0.045
	for cx in [s.x * 0.30, s.x * 0.60]:
		var c := Vector2(cx, s.y * 0.38)
		draw_line(c - Vector2(r, r), c + Vector2(r, r), Color.WHITE, 4.0)
		draw_line(c - Vector2(r, -r), c + Vector2(r, -r), Color.WHITE, 4.0)

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
	queue_redraw()

func set_enraged() -> void:
	_enraged = true
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
	queue_redraw()
