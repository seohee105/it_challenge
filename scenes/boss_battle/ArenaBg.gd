## 보스전 아레나 배경 — 어두운 남색 위에 성(성벽/망루)만 + 보스별 미세 틴트 + 비네트
extends Control

var _tex: Texture2D
var _tint := Color(1, 1, 1)

# 보스별 은은한 색감 (버거=따뜻 / 퀸=원본 / 샐러드=초록기)
const TINTS := [
	Color(1.08, 1.0, 0.96),
	Color(1.0, 1.0, 1.0),
	Color(0.97, 1.05, 0.99),
]

func _ready() -> void:
	_tex = load("res://assets/boss_battle/bg_castle_navy.png")
	resized.connect(queue_redraw)

func set_boss_theme(idx: int) -> void:
	_tint = TINTS[clampi(idx, 0, TINTS.size() - 1)]
	queue_redraw()

func _draw() -> void:
	var s := size
	if _tex:
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, s), false, _tint)
	else:
		draw_rect(Rect2(Vector2.ZERO, s), Color("0f142e"))
	# 아래로 갈수록 서서히 어두운 남색 (경계 없이 부드럽게)
	var top: float = s.y * 0.40
	var steps := 64
	var seg: float = (s.y - top) / steps
	for i in steps:
		var a: float = 0.52 * pow(float(i) / steps, 1.35)   # 완만하게 시작
		draw_rect(Rect2(0, top + seg * i, s.x, seg + 1.0), Color(0.01, 0.01, 0.035, a))
	# 상/좌/우 비네트
	var vg := 66.0
	draw_rect(Rect2(0, 0, s.x, vg), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(0, 0, vg, s.y), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(s.x - vg, 0, vg, s.y), Color(0, 0, 0, 0.18))
