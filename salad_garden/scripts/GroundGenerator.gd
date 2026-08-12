extends Node2D
## 샐러드 가든 타일셋(assets/tiles/ground/ground_XX.png)을 이용해 지면을 랜덤 생성합니다.
## - 평평한 8종 타일 중에서 매번 무작위로 골라 이어붙여서 반복해도 단조롭지 않게 만듭니다.
## - 지면은 타일 1층(플레이어가 서는 윗면)만 두고, 그 아래는 단색으로만 채워서
##   화면 하단까지 빈틈없이 보이게 하되 타일이 여러 겹 쌓여 보이지 않게 합니다.
## - 파이프는 더 이상 여기서 충돌 없는 장식으로 얹지 않는다: LevelBuilder.gd가 발판/상자와
##   같은 균일 배치 시스템에서 콜리전이 있는 장애물(_add_pipe_obstacle)로 직접 배치한다.

@export var start_x: float = 0.0
@export var width: float = 2600.0
@export var top_y: float = 400.0        # 지면 윗면(플레이어가 서는 높이) 월드 좌표
@export var fill_depth: float = 900.0   # 지면 아래로 채울 깊이 (화면 하단까지 여유 있게 커버)
@export var use_rounded_edges: bool = false  # 시작/끝을 둥근 타일로 마감할지 여부
@export var random_seed: int = -1       # -1이면 실행할 때마다 랜덤

const FLAT_TILES: Array[String] = [
	"res://assets/tiles/ground/ground_01.png",
	"res://assets/tiles/ground/ground_02.png",
	"res://assets/tiles/ground/ground_03.png",
	"res://assets/tiles/ground/ground_05.png",
	"res://assets/tiles/ground/ground_06.png",
	"res://assets/tiles/ground/ground_07.png",
	"res://assets/tiles/ground/ground_08.png",
	"res://assets/tiles/ground/ground_10.png",
]
const LEFT_EDGE_TILE := "res://assets/tiles/ground/ground_09.png"
const RIGHT_EDGE_TILE := "res://assets/tiles/ground/ground_04.png"
const FILL_COLOR := Color(0.82, 0.74, 0.52, 1.0)

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	if random_seed >= 0:
		rng.seed = random_seed
	else:
		rng.randomize()
	_build(rng)

func _build(rng: RandomNumberGenerator) -> void:
	var x := start_x
	var first := true
	var tile_h := 100.0
	while x < start_x + width:
		var remaining := (start_x + width) - x
		var tex_path: String
		if use_rounded_edges and first:
			tex_path = LEFT_EDGE_TILE
		elif use_rounded_edges and remaining <= 130.0:
			tex_path = RIGHT_EDGE_TILE
		else:
			tex_path = FLAT_TILES[rng.randi_range(0, FLAT_TILES.size() - 1)]

		var tex: Texture2D = load(tex_path)
		var w := float(tex.get_width())
		var h := float(tex.get_height())
		tile_h = h
		_place_top_tile(tex, x, top_y, w, h)
		x += w
		first = false

	# 지면 아래쪽은 타일을 겹쳐 쌓지 않고 단색으로만 채운다 (지면은 타일 1층만 존재해야 함)
	_fill_underground(top_y + tile_h)

func _fill_underground(fill_top_y: float) -> void:
	var backdrop := ColorRect.new()
	backdrop.color = FILL_COLOR
	backdrop.position = Vector2(start_x, fill_top_y)
	backdrop.size = Vector2(width, fill_depth)
	add_child(backdrop)

func _place_top_tile(tex: Texture2D, x: float, y: float, w: float, h: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.position = Vector2(x, y)
	add_child(sprite)

	var body := StaticBody2D.new()
	body.position = Vector2(x, y)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.shape = rect
	shape.position = Vector2(w / 2.0, h / 2.0)
	body.add_child(shape)
	add_child(body)
