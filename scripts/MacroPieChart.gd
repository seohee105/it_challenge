extends Control
class_name MacroPieChart

## 탄수화물/단백질/지방을 칼로리 기여도(탄4·단4·지9 kcal/g) 비율로 나눈 원형그래프.

const COLOR_CARB := Color(0.35, 0.65, 0.95)
const COLOR_PROTEIN := Color(0.95, 0.45, 0.45)
const COLOR_FAT := Color(0.85, 0.65, 0.2)
const COLOR_EMPTY := Color(0.8, 0.8, 0.8)

var carb_g := 0.0
var protein_g := 0.0
var fat_g := 0.0


func set_macros(carb: float, protein: float, fat: float) -> void:
	carb_g = max(carb, 0.0)
	protein_g = max(protein, 0.0)
	fat_g = max(fat, 0.0)
	queue_redraw()


func _draw() -> void:
	var radius: float = min(size.x, size.y) * 0.5 - 4.0
	var center := size * 0.5
	if radius <= 0.0:
		return

	var carb_kcal := carb_g * 4.0
	var protein_kcal := protein_g * 4.0
	var fat_kcal := fat_g * 9.0
	var total := carb_kcal + protein_kcal + fat_kcal

	if total <= 0.0:
		draw_arc(center, radius, 0.0, TAU, 48, COLOR_EMPTY, 3.0)
		return

	var slices := [
		{"value": carb_kcal, "color": COLOR_CARB},
		{"value": protein_kcal, "color": COLOR_PROTEIN},
		{"value": fat_kcal, "color": COLOR_FAT},
	]

	var start_angle := -PI / 2.0
	for slice in slices:
		var ratio: float = slice["value"] / total
		if ratio <= 0.0:
			continue
		var end_angle: float = start_angle + TAU * ratio
		_draw_pie_slice(center, radius, start_angle, end_angle, slice["color"])
		start_angle = end_angle


func _draw_pie_slice(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color) -> void:
	var points := PackedVector2Array([center])
	var segments: int = max(2, int(64.0 * (end_angle - start_angle) / TAU))
	for i in range(segments + 1):
		var t: float = start_angle + (end_angle - start_angle) * i / float(segments)
		points.append(center + Vector2(cos(t), sin(t)) * radius)
	draw_colored_polygon(points, color)
