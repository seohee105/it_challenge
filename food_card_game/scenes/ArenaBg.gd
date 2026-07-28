## 보스전 아레나 배경 — 던전 타일맵 + 장식(횃불/배너/발판/비네트)
## 보스별 팔레트 테마: 0=버거(그릴 성채) 1=슈가퀸(캔디 궁전) 2=샐러드킹(초록 정원)
extends Control

const T := 26.0
var _t := 0.0
var _theme := 0

const PALS := [
	# ── 0. 그릴 성채 (버거 타이탄): 따뜻한 갈색/레드 석성
	{
		"wall": Color("241a17"), "b_mid": Color("3a2a22"), "b_hi": Color("4a3226"), "b_lo": Color("2e211b"),
		"crack": Color("17100c"),
		"floor": Color("1b120e"), "f_a": Color("35271f"), "f_b": Color("2b201a"), "f_edge": Color("6b4a34"),
		"banner_l": Color("b13a3a"), "banner_r": Color("d9a441"),
		"win_frame": Color("1a0f0a"), "win_pane": Color("6b3320"), "win_glow": Color("ffcf8f"),
		"flame": [Color("d1495b"), Color("e8873b"), Color("f2c14e"), Color("ffe6b0")],
		"torch_glow": Color(0.95, 0.6, 0.25), "plat_l": Color("8fd1ff"), "plat_r": Color("ff9d7a"),
	},
	# ── 1. 캔디 궁전 (슈가 퀸): 핑크/퍼플 사탕 궁
	{
		"wall": Color("3a2140"), "b_mid": Color("5a2f63"), "b_hi": Color("6d3a78"), "b_lo": Color("47264f"),
		"crack": Color("2a1430"),
		"floor": Color("2a1830"), "f_a": Color("5a3466"), "f_b": Color("47264f"), "f_edge": Color("c47fd6"),
		"banner_l": Color("ff7fb0"), "banner_r": Color("7fe0d0"),
		"win_frame": Color("2a1430"), "win_pane": Color("ff7fb0"), "win_glow": Color("fff0f8"),
		"flame": [Color("ff5aa0"), Color("ff8fc4"), Color("ffc2e0"), Color("ffffff")],
		"torch_glow": Color(1.0, 0.5, 0.8), "plat_l": Color("8fd1ff"), "plat_r": Color("ffa0d8"),
	},
	# ── 2. 초록 정원 (시저 샐러드 킹): 그린/온실 채광
	{
		"wall": Color("16281c"), "b_mid": Color("2a4a30"), "b_hi": Color("35603c"), "b_lo": Color("203c26"),
		"crack": Color("0e1c12"),
		"floor": Color("142218"), "f_a": Color("2e4a30"), "f_b": Color("253c28"), "f_edge": Color("7fbf6a"),
		"banner_l": Color("4aa84a"), "banner_r": Color("d9c341"),
		"win_frame": Color("0e1c12"), "win_pane": Color("6fae5a"), "win_glow": Color("eaffea"),
		"flame": [Color("4aa84a"), Color("8fd15a"), Color("cde88b"), Color("f2ffd0")],
		"torch_glow": Color(0.5, 0.9, 0.4), "plat_l": Color("8fd1ff"), "plat_r": Color("9de07a"),
	},
]

func _ready() -> void:
	resized.connect(queue_redraw)
	set_process(true)

func set_boss_theme(idx: int) -> void:
	_theme = clampi(idx, 0, PALS.size() - 1)
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()   # 횃불 깜빡임

func _draw() -> void:
	var pal: Dictionary = PALS[_theme]
	var s := size
	var wall_bot: float = floor(s.y * 0.60 / T) * T

	# ── 벽 (모르타르 + 벽돌, 얼룩덜룩한 음영)
	draw_rect(Rect2(0, 0, s.x, wall_bot), pal.wall)
	var row := 0
	var y := 0.0
	while y < wall_bot:
		var off: float = (T * 0.5) if row % 2 == 1 else 0.0
		var x := -off
		while x < s.x + T:
			var h := int(abs(sin(float(int(x / T)) * 12.9 + row * 7.3)) * 100.0) % 5
			var bc: Color = pal.b_mid
			if h == 0:
				bc = pal.b_hi
			elif h == 1:
				bc = pal.b_lo
			draw_rect(Rect2(x + 1, y + 1, T - 2, T - 2), bc)
			if h == 4:   # 금 간 벽돌
				draw_line(Vector2(x + 5, y + 4), Vector2(x + 12, y + 16), pal.crack, 1.5)
			x += T
		y += T
		row += 1

	# ── 뒤쪽 창문(테마 채광)
	var win := Rect2(s.x * 0.5 - 34, wall_bot * 0.18, 68, wall_bot * 0.5)
	draw_rect(win.grow(4), pal.win_frame)
	draw_rect(win, pal.win_pane)
	draw_circle(Vector2(win.position.x + 22, win.position.y + 22), 12, pal.win_glow)
	draw_line(Vector2(win.position.x + win.size.x * 0.5, win.position.y), Vector2(win.position.x + win.size.x * 0.5, win.end.y), pal.win_frame, 3.0)
	draw_line(Vector2(win.position.x, win.position.y + win.size.y * 0.5), Vector2(win.end.x, win.position.y + win.size.y * 0.5), pal.win_frame, 3.0)

	# ── 배너 (좌/우)
	_banner(s.x * 0.18, wall_bot, pal.banner_l)
	_banner(s.x * 0.82, wall_bot, pal.banner_r)

	# ── 바닥 경계 + 바닥 타일
	draw_rect(Rect2(0, wall_bot - 3, s.x, 3), pal.f_edge)
	draw_rect(Rect2(0, wall_bot, s.x, s.y - wall_bot), pal.floor)
	var frow := 0
	var fy := wall_bot
	while fy < s.y:
		var fx := 0.0
		while fx < s.x:
			var fc: Color = pal.f_a if (int(floor(fx / T)) + frow) % 2 == 0 else pal.f_b
			draw_rect(Rect2(fx + 1, fy + 1, T - 2, T - 2), fc)
			fx += T
		fy += T
		frow += 1

	# ── 파이터 발판 (좌/우)
	_platform(s.x * 0.25, wall_bot + 4, pal.plat_l, pal.f_edge)
	_platform(s.x * 0.75, wall_bot + 4, pal.plat_r, pal.f_edge)

	# ── 횃불 4개 (글로우 + 깜빡이는 불꽃)
	for tx in [0.10, 0.36, 0.64, 0.90]:
		_torch(Vector2(s.x * tx, wall_bot * 0.42), tx, pal)

	# ── 비네트 (가장자리 어둡게)
	var vg := 60.0
	draw_rect(Rect2(0, 0, s.x, vg), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(0, s.y - vg, s.x, vg), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(0, 0, vg, s.y), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(s.x - vg, 0, vg, s.y), Color(0, 0, 0, 0.18))

func _banner(cx: float, ref_y: float, col: Color, small := false) -> void:
	var w := 30.0
	var top := (size.y * 0.02) if not small else ref_y
	var h := (ref_y * 0.42) if not small else (size.y * 0.14)
	var r := Rect2(cx - w * 0.5, top, w, h)
	draw_rect(r.grow(2), col.darkened(0.4))
	draw_rect(r, col)
	# 펜넌트 갈래
	var notch := PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(cx, r.end.y - 9)])
	draw_colored_polygon(notch, Color("1b2036"))
	draw_circle(Vector2(cx, top + h * 0.42), 5.0, col.lightened(0.35))

func _platform(cx: float, top: float, tint: Color, edge: Color) -> void:
	for i in 3:
		var ww := 96.0 - i * 20.0
		draw_rect(Rect2(cx - ww * 0.5, top + i * 5.0, ww, 6.0), Color(tint.r, tint.g, tint.b, 0.10 - i * 0.02))
	draw_rect(Rect2(cx - 52, top, 104, 5.0), edge)

func _torch(pos: Vector2, seed: float, pal: Dictionary) -> void:
	var f := 0.82 + 0.18 * sin(_t * 9.0 + seed * 30.0) + 0.06 * sin(_t * 21.0 + seed * 11.0)
	var g: Color = pal.torch_glow
	# 글로우
	draw_circle(pos, 42.0 * f, Color(g.r, g.g, g.b, 0.06))
	draw_circle(pos, 26.0 * f, Color(g.r, g.g, g.b, 0.09))
	# 브래킷
	draw_rect(Rect2(pos.x - 3, pos.y + 4, 6, 16), Color("2a2233"))
	draw_rect(Rect2(pos.x - 7, pos.y + 18, 14, 4), Color("3a3040"))
	# 불꽃
	var fl: Array = pal.flame
	draw_circle(pos + Vector2(0, 1), 8.0 * f, fl[0])
	draw_circle(pos, 6.5 * f, fl[1])
	draw_circle(pos - Vector2(0, 4.0 * f), 4.2 * f, fl[2])
	draw_circle(pos - Vector2(0, 7.5 * f), 2.4 * f, fl[3])
