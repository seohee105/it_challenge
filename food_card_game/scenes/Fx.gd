## 전투 이펙트 모음 — 카드 이름에 맞춘 다양한 연출 (코드 드로잉 + 트윈, 자동 소멸)
## Main에서 preload 후 정적 함수로 호출.
##   Fx.burst(parent, pos, style, accent)  — 타격/방어/회복 등 스타일별 폭발
##   Fx.make_proj(color, style)            — 공격 발사체 (모양이 스타일별로 다름)
##   Fx.popup(parent, pos, text, color)    — 데미지/회복 숫자 팝업
extends RefCounted

# ── 스타일별 확산 이펙트
class Burst extends Control:
	const S := 2.4   # 이펙트 전체 확대 배율
	var style := "impact"
	var accent := Color.WHITE
	var t := 0.0

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * S)
		var a := 1.0 - t
		match style:
			# ── 공격 타격
			"protein_shot":
				var r: float = lerp(6.0, 40.0, t)
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(Color("ff6f6f"), a), 4.0)
				_fill_star(Vector2.ZERO, lerp(10.0, 34.0, t), lerp(4.0, 12.0, t), 4, 0.0, Color(1, 1, 1, a))
			"fat_slide":
				for i in 8:
					var ang := TAU * i / 8.0
					var d: float = lerp(4.0, 40.0, t)
					var p := Vector2(cos(ang) * 1.4, sin(ang) * 0.65) * d
					draw_circle(p, lerp(10.0, 3.0, t), Color(Color("caa06a"), a))
			"butter":
				draw_arc(Vector2.ZERO, lerp(8.0, 38.0, t), 0.0, TAU, 28, Color(Color("f2c14e"), a * 0.7), 5.0)
				for i in 8:
					var ang := TAU * i / 8.0 + 0.2
					draw_circle(Vector2(cos(ang), sin(ang)) * lerp(6.0, 44.0, t), lerp(6.0, 2.0, t), Color(Color("ffe08a"), a))
			"boom":
				var r1: float = lerp(8.0, 56.0, t)
				var r2: float = lerp(0.0, 42.0, t)
				draw_arc(Vector2.ZERO, r1, 0.0, TAU, 40, Color(1, 1, 1, a), 6.0)
				draw_arc(Vector2.ZERO, r2, 0.0, TAU, 40, Color(Color("ff9d5a"), a), 8.0)
				for i in 10:
					var ang := TAU * i / 10.0
					var dir := Vector2(cos(ang), sin(ang))
					draw_line(dir * r1 * 0.6, dir * r1 * 1.15, Color(Color("ffd36b"), a), 4.0)
				for i in 8:
					var ang2 := TAU * i / 8.0 + 0.3
					draw_circle(Vector2(cos(ang2), sin(ang2)) * lerp(10.0, 52.0, t), 3.0, Color(Color("8a5a2a"), a))
			# ── 방어
			"spikes":
				var r: float = lerp(16.0, 40.0, t)
				for i in 12:
					var ang := TAU * i / 12.0
					var dir := Vector2(cos(ang), sin(ang))
					var perp := Vector2(-dir.y, dir.x) * 5.0
					draw_colored_polygon(PackedVector2Array([dir * r + perp, dir * r - perp, dir * (r + 11.0)]), Color(Color("ffd45e"), a))
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(Color("ffd45e"), a * 0.6), 3.0)
			"hex":
				_hex(lerp(22.0, 44.0, t), Color(Color("7ec3ff"), a), 5.0)
				_hex(lerp(14.0, 30.0, t), Color(Color("bfe0ff"), a * 0.6), 3.0)
			"avocado":
				var r: float = lerp(18.0, 42.0, t)
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(Color("8ce39b"), a), 7.0)
				draw_circle(Vector2.ZERO, r * 0.42, Color(Color("7a4a2a"), a))
				draw_circle(Vector2(-r * 0.14, -r * 0.14), r * 0.12, Color(1, 1, 1, a * 0.7))
			# ── 회복
			"sugar_rush":
				for i in 11:
					var ang := TAU * i / 11.0 + t * 3.0
					var d: float = lerp(4.0, 46.0, t)
					_fill_star(Vector2(cos(ang), sin(ang)) * d, (1.0 - t) * 6.0 + 3.0, 2.0, 4, t * 4.0, Color(Color("f7a8cf"), a))
			"carb":
				for i in 6:
					var x: float = lerp(-18.0, 18.0, float(i) / 5.0)
					var y: float = -lerp(0.0, 42.0, t) + sin(float(i)) * 6.0
					_plus(Vector2(x, y), 5.0, Color(Color("e0a35a"), a))
			"inject":
				var yl: float = lerp(-42.0, 0.0, min(t * 2.0, 1.0))
				draw_line(Vector2(0, yl - 16), Vector2(0, yl), Color(Color("8ce39b"), a), 5.0)
				if t > 0.4:
					var rr: float = lerp(6.0, 34.0, (t - 0.4) / 0.6)
					draw_arc(Vector2.ZERO, rr, 0.0, TAU, 28, Color(Color("8ce39b"), 1.0 - t), 4.0)
			"kick":
				var a0 := -0.6 + t * 1.4
				draw_arc(Vector2(-6, 2), lerp(14.0, 30.0, t), a0, a0 + 1.7, 20, Color(Color("f4a7c0"), a), 6.0)
				for i in 4:
					var dir := Vector2(cos(TAU * i / 4.0), sin(TAU * i / 4.0))
					draw_line(dir * lerp(4.0, 20.0, t), dir * lerp(8.0, 28.0, t), Color(Color("ffd0e2"), a), 3.0)
			"leap":
				for i in 3:
					var yy: float = -lerp(0.0, 38.0, t) - i * 12.0
					var w: float = 12.0 - i * 2.0
					draw_line(Vector2(-w, yy + 8), Vector2(0, yy), Color(Color("9be3a0"), a), 4.0)
					draw_line(Vector2(w, yy + 8), Vector2(0, yy), Color(Color("9be3a0"), a), 4.0)
				draw_arc(Vector2(0, 16), lerp(6.0, 26.0, t), 0.0, PI, 16, Color(Color("cbb89a"), a * 0.7), 3.0)
			# ── 보스/기본
			"shield":
				_hex(lerp(18.0, 46.0, t), Color(accent, a), 6.0)
			"heal":
				for i in 6:
					var ang := TAU * i / 6.0 - t * 1.5
					_plus(Vector2(cos(ang), sin(ang)) * lerp(6.0, 42.0, t), 6.0, Color(accent, a))
			_:  # "impact" 기본
				var r: float = lerp(6.0, 48.0, t)
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(accent, a), 5.0)
				for i in 8:
					var dir := Vector2(cos(TAU * i / 8.0), sin(TAU * i / 8.0))
					draw_line(dir * r * 0.7, dir * r * 1.2, Color(accent, a), 3.0)

	func _plus(p: Vector2, s: float, c: Color) -> void:
		draw_line(p - Vector2(s, 0), p + Vector2(s, 0), c, 3.0)
		draw_line(p - Vector2(0, s), p + Vector2(0, s), c, 3.0)

	func _fill_star(center: Vector2, r_out: float, r_in: float, points: int, phase: float, c: Color) -> void:
		var pts := PackedVector2Array()
		for i in points * 2:
			var rr := r_out if i % 2 == 0 else r_in
			var ang := PI * i / points + phase
			pts.append(center + Vector2(cos(ang), sin(ang)) * rr)
		draw_colored_polygon(pts, c)

	func _hex(r: float, c: Color, width: float) -> void:
		var pts := PackedVector2Array()
		for i in 7:
			var ang := PI / 3.0 * i - PI / 6.0
			pts.append(Vector2(cos(ang), sin(ang)) * r)
		draw_polyline(pts, c, width)

# ── 발사체 (공격 카드, 스타일별 모양)
class Proj extends Control:
	const S := 2.2   # 발사체 확대 배율
	var color := Color.WHITE
	var shape := "circle"

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * S)
		match shape:
			"bullet":
				draw_line(Vector2(-11, 0), Vector2(11, 0), color, 13.0)
				draw_circle(Vector2(9, 0), 4.0, Color(1, 1, 1, 0.7))
			"blob":
				draw_circle(Vector2(-7, 0), 9.0, color)
				draw_circle(Vector2(7, 0), 9.0, color)
				draw_circle(Vector2.ZERO, 11.0, color)
			"pat":
				draw_set_transform(Vector2.ZERO, 0.5, Vector2.ONE * S)
				draw_rect(Rect2(-12, -9, 24, 18), Color("f2c14e"))
				draw_rect(Rect2(-12, -9, 24, 6), Color("ffe08a"))
			"orb":
				draw_circle(Vector2.ZERO, 16.0, color.darkened(0.1))
				draw_circle(Vector2(-4, -4), 6.0, Color(1, 1, 1, 0.4))
				draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 24, Color(color, 0.4), 3.0)
			"energy":
				draw_circle(Vector2.ZERO, 20.0, Color(color, 0.22))
				draw_circle(Vector2.ZERO, 13.0, Color(color, 0.55))
				draw_circle(Vector2.ZERO, 8.0, color)
				draw_circle(Vector2(-2, -2), 4.0, Color(1, 1, 1, 0.95))
				draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 28, Color(color, 0.4), 3.0)
			_:
				draw_circle(Vector2.ZERO, 13.0, color)
				draw_circle(Vector2(-3, -3), 5.0, Color(1, 1, 1, 0.6))
				draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 24, Color(color, 0.35), 3.0)

# ────────────────────────────── 스폰
static func burst(parent: Node, pos: Vector2, style: String, accent := Color.WHITE) -> void:
	var b := Burst.new()
	b.style = style
	b.accent = accent
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.z_index = 90
	parent.add_child(b)
	b.position = pos
	var dur := 0.7 if style == "boom" else 0.55
	var t := b.create_tween()
	t.tween_method(func(v): b.t = v; b.queue_redraw(), 0.0, 1.0, dur)
	t.tween_callback(b.queue_free)

static func popup(parent: Node, pos: Vector2, text: String, color: Color, big := false) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 56 if big else 38)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 100
	l.size = Vector2(140, 44)
	parent.add_child(l)
	l.position = pos - Vector2(70, 26)
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 62, 0.75).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.75).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(l.queue_free)

static func make_proj(color: Color, style := "circle") -> Control:
	var p := Proj.new()
	p.color = color
	p.shape = _proj_shape(style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 95
	return p

static func _proj_shape(style: String) -> String:
	match style:
		"protein_shot": return "bullet"
		"fat_slide": return "blob"
		"butter": return "pat"
		"boom": return "orb"
		"energy": return "energy"
		"orb": return "orb"
		_: return "circle"

# 방어막 링 (일정 시간 유지 후 사라짐)
static func aura(parent: Node, pos: Vector2, color: Color, dur: float, radius := 96.0) -> void:
	var a := Aura.new()
	a.color = color
	a.rmax = radius
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a.z_index = 88
	parent.add_child(a)
	a.position = pos
	var t := a.create_tween()
	t.tween_method(func(v): a.grow = v; a.queue_redraw(), 0.0, 1.0, 0.22)   # 나타남
	t.tween_interval(max(0.1, dur - 0.7))                                    # 유지
	t.parallel().tween_method(func(v): a.grow = v; a.queue_redraw(), 1.0, 1.0, max(0.1, dur - 0.7))
	t.tween_method(func(v): a.fade = v; a.queue_redraw(), 1.0, 0.0, 0.4)     # 사라짐
	t.tween_callback(a.queue_free)

class Aura extends Control:
	var color := Color("6be37a")
	var grow := 0.0
	var fade := 1.0
	var rmax := 96.0
	func _draw() -> void:
		var r: float = lerp(rmax * 0.64, rmax, clampf(grow, 0.0, 1.0))
		var pulse := 1.0 + 0.05 * sin(grow * 30.0)
		draw_circle(Vector2.ZERO, r * pulse, Color(color, 0.14 * fade))
		draw_arc(Vector2.ZERO, r * pulse, 0.0, TAU, 48, Color(color, 0.9 * fade), 7.0)
		draw_arc(Vector2.ZERO, r * pulse * 0.82, 0.0, TAU, 48, Color(color, 0.45 * fade), 4.0)
