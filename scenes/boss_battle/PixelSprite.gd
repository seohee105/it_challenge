## 픽셀아트 스프라이트 렌더러 — rows(문자 그리드)를 정수배 픽셀로 크리스프하게 그림
class_name PixelSprite
extends Control

var rows: Array = []
var palette := {}
var tint := Color(1, 1, 1, 1)   # 광폭화 등 색조 변경용

func setup(r: Array, pal: Dictionary) -> void:
	rows = r
	palette = pal
	queue_redraw()

func _draw() -> void:
	if rows.is_empty():
		return
	var cols := 0
	for r in rows:
		cols = max(cols, (r as String).length())
	var n := rows.size()
	if cols == 0 or n == 0:
		return
	var ps: float = floor(min(size.x / float(cols), size.y / float(n)))
	if ps < 1.0:
		ps = 1.0
	var ox: float = floor((size.x - ps * cols) * 0.5)
	var oy: float = floor((size.y - ps * n) * 0.5)
	for y in n:
		var line: String = rows[y]
		for x in line.length():
			var ch := line[x]
			if palette.has(ch):
				var col: Color = palette[ch]
				if tint != Color(1, 1, 1, 1):
					col = col * tint
				draw_rect(Rect2(ox + x * ps, oy + y * ps, ps, ps), col)
