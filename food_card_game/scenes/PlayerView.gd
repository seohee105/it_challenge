## 플레이어 캐릭터 — 이미지 프레임 렌더 + 화려한 액션(돌진/회전/스쿼시·스트레치/잔상)
class_name PlayerView
extends Control

const MAX_SCALE := 2.2   # 도트 배율 상한 (작을수록 픽셀이 촘촘)

var _tex_idle: Texture2D
var _tex_attack: Texture2D
var _tex_hit: Texture2D
var _state := "idle"            # idle / attack / hit
var _flash_col := Color.WHITE
var _flash := 0.0

# 트랜스폼(발 밑 피벗 기준)
var _ox := 0.0
var _oy := 0.0
var _rot := 0.0
var _scl := Vector2.ONE
var _after := 0.0              # 잔상 강도(0~1)
var _idle := 0.0
var _t := 0.0
var _anim: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(210, 325)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_character("player")

func set_character(name: String) -> void:
	_tex_idle = _load("res://assets/%s_idle.png" % name)
	if _tex_idle == null:
		if name != "player":
			set_character("player")
		return
	_tex_attack = _load("res://assets/%s_attack.png" % name)
	_tex_hit = _load("res://assets/%s_hit.png" % name)
	if _tex_attack == null:
		_tex_attack = _tex_idle
	if _tex_hit == null:
		_tex_hit = _tex_idle
	queue_redraw()

func set_sprite(name: String) -> void:
	set_character(name)

func sprite_rect_global() -> Rect2:
	var s := size
	var tex: Texture2D = _tex_idle
	if tex == null:
		return get_global_rect()
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var sc: float = minf(min(s.x / tw, s.y / th), MAX_SCALE)
	var dw := tw * sc
	var dh := th * sc
	return Rect2(global_position + Vector2((s.x - dw) * 0.5, s.y - dh - 6.0), Vector2(dw, dh))

func _load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _process(delta: float) -> void:
	_t += delta
	_idle = sin(_t * 2.2) * 2.5
	queue_redraw()

func _draw() -> void:
	var s := size
	var tex: Texture2D = _tex_idle
	if _state == "attack" and _tex_attack != null:
		tex = _tex_attack
	elif _state == "hit" and _tex_hit != null:
		tex = _tex_hit
	if tex == null:
		return
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var sc: float = minf(min(s.x / tw, s.y / th), MAX_SCALE)
	var dw := tw * sc
	var dh := th * sc
	var feet := Vector2(s.x * 0.5, s.y - 6.0)          # 발 밑 피벗
	var rel := Rect2(-dw * 0.5, -dh, dw, dh)            # 피벗 기준 스프라이트 위치

	# ── 잔상(공격 시 초록 모션 트레일)
	if _after > 0.01:
		for i in 3:
			var f: float = 0.42 + 0.19 * i
			var ga: float = (0.10 + 0.07 * i) * _after
			draw_set_transform(feet + Vector2(_ox * f, (_oy + _idle) * f), _rot * f, Vector2.ONE.lerp(_scl, f))
			draw_texture_rect(tex, rel, false, Color(0.55, 1.0, 0.7, ga))

	# ── 본체
	draw_set_transform(feet + Vector2(_ox, _oy + _idle), _rot, _scl)
	draw_texture_rect(tex, rel, false)
	if _flash > 0.0:
		draw_texture_rect(tex, rel, false, Color(_flash_col.r, _flash_col.g, _flash_col.b, _flash))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _fresh() -> Tween:
	if _anim != null and _anim.is_valid():
		_anim.kill()
	_anim = create_tween()
	return _anim

# ── 공격: 예비동작 → 돌진(기울임+스트레치+잔상) → 탄성 복귀
func play_attack() -> void:
	_state = "attack"
	_after = 1.0
	var t := _fresh()
	# 1) 예비 (뒤로 웅크림)
	t.tween_method(_a_ox, _ox, -16.0, 0.08).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_method(_a_rot, _rot, -0.14, 0.08)
	t.parallel().tween_method(_a_sx, _scl.x, 1.14, 0.08)
	t.parallel().tween_method(_a_sy, _scl.y, 0.86, 0.08)
	# 2) 돌진 (앞으로 확 + 기울임 + 스트레치)
	t.tween_method(_a_ox, -16.0, 56.0, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_a_rot, -0.14, 0.30, 0.10)
	t.parallel().tween_method(_a_sx, 1.14, 0.80, 0.10)
	t.parallel().tween_method(_a_sy, 0.86, 1.22, 0.10)
	# 3) 탄성 복귀
	t.tween_method(_a_ox, 56.0, 0.0, 0.34).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_a_rot, 0.30, 0.0, 0.34).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_a_sx, 0.80, 1.0, 0.34).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_a_sy, 1.22, 1.0, 0.34).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_a_after, 1.0, 0.0, 0.30)
	t.chain().tween_callback(_to_idle)

# ── 방어: 웅크리며 브레이스(스쿼시) → 튕겨 복귀 + 파란 번쩍
func play_defense() -> void:
	_flash_to(Color("8fd1ff"))
	var t := _fresh()
	t.tween_method(_a_sy, _scl.y, 0.80, 0.09).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_method(_a_sx, _scl.x, 1.20, 0.09)
	t.parallel().tween_method(_a_oy, _oy, 12.0, 0.09)
	t.tween_method(_a_sy, 0.80, 1.0, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_a_sx, 1.20, 1.0, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_a_oy, 12.0, 0.0, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# ── 회복: 살짝 커졌다 복귀 + 초록 번쩍
func play_heal() -> void:
	_flash_to(Color("8ce39b"))
	var t := _fresh()
	t.tween_method(_a_sy, _scl.y, 1.14, 0.14).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_method(_a_sx, _scl.x, 1.08, 0.14)
	t.tween_method(_a_sy, 1.14, 1.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_a_sx, 1.08, 1.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# ── 피격: 뒤로 밀림 + 기울임 + 탄성 흔들림 + 빨강 번쩍
func hurt() -> void:
	_state = "hit"
	_flash_to(Color("ff8a8a"))
	var t := _fresh()
	t.tween_method(_a_ox, _ox, -36.0, 0.08).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_a_rot, _rot, -0.24, 0.08)
	t.parallel().tween_method(_a_sx, _scl.x, 1.12, 0.08)
	t.parallel().tween_method(_a_sy, _scl.y, 0.9, 0.08)
	t.tween_method(_a_ox, -36.0, 0.0, 0.42).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_a_rot, -0.24, 0.0, 0.42).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_a_sx, 1.12, 1.0, 0.42).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_a_sy, 0.9, 1.0, 0.42).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(_to_idle)

func _to_idle() -> void:
	_state = "idle"
	_ox = 0.0; _oy = 0.0; _rot = 0.0; _scl = Vector2.ONE; _after = 0.0
	queue_redraw()

func _flash_to(c: Color) -> void:
	_flash_col = c
	var f := create_tween()
	f.tween_method(_set_flash, 0.75, 0.0, 0.3)

func _a_ox(v: float) -> void: _ox = v; queue_redraw()
func _a_oy(v: float) -> void: _oy = v; queue_redraw()
func _a_rot(v: float) -> void: _rot = v; queue_redraw()
func _a_sx(v: float) -> void: _scl.x = v; queue_redraw()
func _a_sy(v: float) -> void: _scl.y = v; queue_redraw()
func _a_after(v: float) -> void: _after = v; queue_redraw()
func _set_flash(v: float) -> void: _flash = v; queue_redraw()
