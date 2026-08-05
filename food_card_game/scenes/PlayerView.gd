## 플레이어 캐릭터 — 이미지 프레임 렌더 (대기/공격/피격 상태 + 들썩임/돌진/번쩍임)
class_name PlayerView
extends Control

var _tex_idle: Texture2D
var _tex_attack: Texture2D
var _tex_hit: Texture2D
var _state := "idle"            # idle / attack / hit
var _flash_col := Color.WHITE
var _flash := 0.0
var _ox := 0.0
var _idle := 0.0
var _t := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(210, 325)   # 보스 뷰와 높이 맞춤(체력바 정렬 + 전신 표시)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 도트 선명하게
	set_character("player")

## 캐릭터 전환 — assets/{name}_idle|attack|hit.png 로드 (없으면 player로 폴백)
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

# 기존 전환 구조 호환 (Save.char_id)
func set_sprite(name: String) -> void:
	set_character(name)

## 실제로 그려지는 스프라이트의 전역 사각형 (_draw와 동일 계산) — 이펙트 정렬용
func sprite_rect_global() -> Rect2:
	var s := size
	var tex: Texture2D = _tex_idle
	if tex == null:
		return get_global_rect()
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var sc: float = minf(min(s.x / tw, s.y / th), 2.7)
	var dw := tw * sc
	var dh := th * sc
	return Rect2(global_position + Vector2((s.x - dw) * 0.5, s.y - dh - 6.0), Vector2(dw, dh))

func _load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _process(delta: float) -> void:
	_t += delta
	_idle = sin(_t * 2.2) * 2.5   # 대기 들썩임
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
	draw_set_transform(Vector2(_ox, _idle), 0.0, Vector2.ONE)
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var sc: float = min(s.x / tw, s.y / th)
	sc = minf(sc, 2.7)               # 스케일 상한 (캐릭터 조금 작게)
	var dw := tw * sc
	var dh := th * sc
	var r := Rect2((s.x - dw) * 0.5, s.y - dh - 6.0, dw, dh)   # 바닥 정렬
	draw_texture_rect(tex, r, false)
	if _flash > 0.0:
		draw_texture_rect(tex, r, false, Color(_flash_col.r, _flash_col.g, _flash_col.b, _flash))

func play_attack() -> void:
	_state = "attack"
	var t := create_tween()
	t.tween_method(_set_ox, 0.0, 40.0, 0.09).set_ease(Tween.EASE_OUT)
	t.tween_method(_set_ox, 40.0, 0.0, 0.26).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(_to_idle)

func play_defense() -> void:
	_flash_to(Color("8fd1ff"))

func play_heal() -> void:
	_flash_to(Color("8ce39b"))

func hurt() -> void:
	_state = "hit"
	_flash_to(Color("ff8a8a"))
	var t := create_tween()
	t.tween_interval(0.32)
	t.tween_callback(_to_idle)

func _to_idle() -> void:
	_state = "idle"
	queue_redraw()

func _flash_to(c: Color) -> void:
	_flash_col = c
	var t := create_tween()
	t.tween_method(_set_flash, 0.7, 0.0, 0.3)

func _set_ox(v: float) -> void:
	_ox = v
	queue_redraw()

func _set_flash(v: float) -> void:
	_flash = v
	queue_redraw()
