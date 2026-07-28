## 플레이어 캐릭터 — 도트 스프라이트 렌더 (공격/방어/회복/피격 연출)
class_name PlayerView
extends Control

const PixelsData := preload("res://scenes/Pixels.gd")

var _flash_col := Color.WHITE
var _flash := 0.0
var _ox := 0.0
var _oy := 0.0
var _idle := 0.0
var _t := 0.0
var _spr := "hero"   # 현재 캐릭터 도트 스프라이트 (전환 구조용)

func _ready() -> void:
	custom_minimum_size = Vector2(200, 222)

## 유저 캐릭터 전환 — Pixels.gd 스프라이트 이름 지정
func set_sprite(name: String) -> void:
	if name == "" or not (name in PixelsData.ICONS):
		name = "hero"   # 없는 스프라이트면 기본값
	_spr = name
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	_idle = sin(_t * 2.2) * 2.0   # 가만히 있을 때 위아래 들썩임
	queue_redraw()

func _draw() -> void:
	var s := size
	draw_set_transform(Vector2(_ox, _oy + _idle), 0.0, Vector2.ONE)
	var rect := Rect2(0, 0, s.x, s.y)
	PixelsData.draw_grid(self, PixelsData.icon(_spr), PixelsData.PAL, rect)
	if _flash > 0.0:
		PixelsData.draw_grid(self, PixelsData.icon(_spr), PixelsData.PAL, rect, Color(1, 1, 1, 1), Color(_flash_col.r, _flash_col.g, _flash_col.b, _flash))

func play_attack() -> void:
	var t := create_tween()
	t.tween_method(_set_ox, 0.0, 36.0, 0.09).set_ease(Tween.EASE_OUT)
	t.tween_method(_set_ox, 36.0, 0.0, 0.24).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func play_defense() -> void:
	_flash_to(Color("8fd1ff"))

func play_heal() -> void:
	_flash_to(Color("8ce39b"))
	var t := create_tween()
	t.tween_method(_set_oy, 0.0, -14.0, 0.15)
	t.tween_method(_set_oy, -14.0, 0.0, 0.22)

func hurt() -> void:
	_flash_to(Color("ff6b6b"))
	var t := create_tween()
	t.tween_method(_set_ox, 14.0, 0.0, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _flash_to(c: Color) -> void:
	_flash_col = c
	var t := create_tween()
	t.tween_method(_set_flash, 0.72, 0.0, 0.35)

func _set_ox(v: float) -> void:
	_ox = v
	queue_redraw()

func _set_oy(v: float) -> void:
	_oy = v
	queue_redraw()

func _set_flash(v: float) -> void:
	_flash = v
	queue_redraw()
