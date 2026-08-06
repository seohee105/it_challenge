extends Node2D
## 발판/상자/파이프/적/아이템을 각각 맵 전체(0~8400)에 걸친 균일 무작위 칸(버킷) 방식으로
## 배치해서 특정 구간에 몰리지 않고 고르게 퍼지게 한다. 움직이는(레일) 발판은 삭제했다.
## 완결 지점 장식만은 연출을 위해 고정 배치로 남겨뒀다.
## 상점/코인 소비, 보스전은 요청에 따라 제외.

const EnemyScene := preload("res://scenes/Enemy.tscn")
const ItemScene := preload("res://scenes/Item.tscn")

const GROUND_TOP_Y: float = 400.0
const ITEM_Y: float = 386.0
## 점프로 실제로 닿을 수 있는 최대 높이는 이론상 265px(Player.gd의 JUMP_VELOCITY_HIGH -720 / GRAVITY 980 기준)이다.
## 발판 윗면을 더 높이 올려서(y값은 더 작게) GROUND_TOP_Y에서 205~235px 낮은 범위(y=165~195)에 둔다:
##  - 발판 아래쪽(발판 높이 ~103px 포함)이 지면 윗면(400)보다 훨씬 위에서 끝나서 확실히 떠 있어 보이고,
##  - 그러면서도 점프 최대 높이(265px) 안쪽에 여유 있게(30px 이상) 들어와서 항상 뛰어서 닿을 수 있다.
## 발판을 더 높이는 만큼 Player.gd의 JUMP_VELOCITY_HIGH도 같이 올려야 한다 (그러지 않으면 통과 불가 문제가 생긴다).
## 평소 점프는 낮은 JUMP_VELOCITY_LOW를 쓰고, 발판에 올라타야 하는 순간에만 JUMP_VELOCITY_HIGH를 쓰도록
## _add_platform_trigger()가 발판 앞에 보이지 않는 트리거 구역을 물리 계산으로 깔아둔다 (아래 참고).
const PLATFORM_Y_BASE: float = 180.0
const PLATFORM_Y_JITTER: float = 15.0  # 매 발판마다 살짝 다른 높이를 주기 위한 무작위 폭

## 아래 세 값은 Player.gd의 GRAVITY / JUMP_VELOCITY_HIGH / FORWARD_SPEED와 반드시 같아야 한다.
## _add_platform_trigger()가 포물선 운동 공식으로 "발판에 안전하게 착지하는 점프 타이밍 구간"을
## 계산하는 데 쓰인다 (Player.gd 쪽 값이 바뀌면 이 세 상수도 같이 맞춰야 한다).
const PLAYER_GRAVITY: float = 980.0
const PLAYER_JUMP_VELOCITY_HIGH: float = -720.0
const PLAYER_FORWARD_SPEED: float = 169.4

## 발판은 낱개가 아니라 지면 타일 3~4개를 이어붙인 "한 줄"로 등장한다.
const PLATFORM_ROW_MIN_TILES: int = 3
const PLATFORM_ROW_MAX_TILES: int = 4

## 아이템은 일반 점프(심지어 걷기)만으로도 항상 닿을 수 있는 높이에 고정한다:
## 지면 윗면(400)에서 70px 위 -> 플레이어 콜리전(72px)이 걸어 다닐 때도 겹치고,
## 점프 최대 높이(265px)에는 195px나 여유가 있어 발판이 실제로 있는지와 무관하게 항상 먹을 수 있다.
## (예전에는 "발판 위에서만 닿는" y=110 공중 아이템이 있었는데, 발판 등장이 무작위라 그 발판이
## 스킵되면 아이템만 남아 일반 점프로는 절대 못 먹는 위치가 되는 문제가 있어서 폐지했다.)
const ITEM_SAFE_Y: float = 330.0

# ---------------- 장애물/적: 맵 전체에 "하나의 칸 체계"로 균일 배치 ----------------
## 예전에는 발판/상자와 적을 서로 다른 칸 크기(500px, 350px)로 독립적으로 굴려서, 운이 나쁘면
## 적과 발판/상자가 거의 같은 x에 겹쳐 나오는 경우가 생겼다. 이러면 둘 다 지나가려면 좁은 틈에서
## 착지와 동시에 다시 점프해야 하는데, 적이 순찰하며 그 틈으로 다시 들어오면 사실상 진행이 막혀
## "게임이 진행되지 않는" 것처럼 보이는 상황이 나온다. 이를 막기 위해 발판/상자/적을 전부 같은
## 칸(버킷) 하나에서 서로 배타적으로(한 칸에 하나만) 골라서 절대 겹치지 않게 한다.
const HAZARD_ZONE_START: float = 700.0  # 시작 지점은 장애물 없는 완충 구간으로 비워둔다
const HAZARD_ZONE_END: float = 8250.0   # 완결 지점 장식(약 8320~) 앞에서 멈춘다
## 발판 한 줄이 최대 4타일(약 410px)까지 차지할 수 있으므로, 칸 크기(500px)와 칸 안에서의
## 시작 위치 제한(최대 70px)을 합쳐도 다음 칸으로 절대 넘어가지 않게 한다.
const HAZARD_BUCKET_SIZE: float = 500.0
const HAZARD_START_JITTER: float = 70.0
const HAZARD_SKIP_CHANCE: float = 0.22     # 칸마다 22% 확률로 아무것도 두지 않는다
const ENEMY_ZONE_START: float = 800.0      # 1구역(튜토리얼)에는 적을 두지 않는다
## 적 등장 확률을 75%로 지정한다.
const ENEMY_CHANCE: float = 0.75           # 무언가 나오는 칸 중 75%는 적, 나머지는 발판/상자/파이프
## 일반 발판(행) 등장 확률을 75%로 지정한다.
const PLATFORM_CHANCE: float = 0.75        # 적이 아닐 때, 그중 75%는 일반 발판(행)
## 발판이 아닐 때, 상자/파이프 중 파이프 쪽 비중. 파이프는 예전엔 GroundGenerator가 충돌 없는
## 순수 장식으로 심었는데, 상자처럼 플레이어가 올라탈 수 있어야 해서 콜리전이 있는 장애물로
## 옮기고 장식용 배치는 없앴다 (두 시스템이 따로 놀면 서로 겹쳐 보이는 문제도 생기기 때문).
const PIPE_CHANCE: float = 0.5

const ENEMY_TYPES: Array[String] = ["tomato", "broccoli", "avocado", "bokchoy"]

## 아이템도 위와 같은 방식으로 맵 전체를 균일한 칸으로 나눠서 고르게 등장시킨다
## (예전에는 구역마다 2~3개씩 수동으로 심어서 구역별 밀도가 들쭉날쭉했다). 발판/상자/적과는
## 칸 크기가 달라 서로 독립적으로 겹칠 수 있지만, 아이템은 충돌체가 없어 겹쳐도 진행을 막지 않는다.
const ITEM_ZONE_START: float = 300.0
const ITEM_ZONE_END: float = 8300.0
const ITEM_BUCKET_SIZE: float = 350.0
## 아이템 등장 확률을 95%로 지정한다(스킵 확률 5%).
const ITEM_SKIP_CHANCE: float = 0.05
const ITEM_TYPE_COUNT: int = 3 # Item.gd의 ItemType 개수: HEART=0, ATTACK=1, SHIELD=2

func _ready() -> void:
	_build_random_hazards()
	_build_random_items()
	_build_finish_decoration()

## 700~8250 구간을 500px 칸으로 나눠서, 칸마다 발판 행 / 상자 / 파이프 / 적 / 아무것도 없음
## 중 하나만 무작위로 고른다. 한 칸에는 하나만 나오므로 서로 절대 겹치지 않으면서 맵 전체에
## 고르게 퍼진다 (적은 튜토리얼 구간(<800)에는 두지 않는다).
func _build_random_hazards() -> void:
	var x := HAZARD_ZONE_START
	while x < HAZARD_ZONE_END:
		if randf() >= HAZARD_SKIP_CHANCE:
			var spawn_x: float = x + randf() * HAZARD_START_JITTER
			if x >= ENEMY_ZONE_START and randf() < ENEMY_CHANCE:
				var enemy_type: String = ENEMY_TYPES[randi() % ENEMY_TYPES.size()]
				var patrol: float = randf_range(20.0, 70.0)
				var speed: float = randf_range(45.0, 60.0)
				_add_enemy(spawn_x, ITEM_Y, enemy_type, patrol, speed)
			elif randf() < PLATFORM_CHANCE:
				_add_platform_row(spawn_x, _row_y())
			elif randf() < PIPE_CHANCE:
				_add_pipe_obstacle(spawn_x, PIPE_TEXTURES[randi() % PIPE_TEXTURES.size()])
			else:
				_add_box_obstacle(spawn_x, BOX_TEXTURES[randi() % BOX_TEXTURES.size()])
		x += HAZARD_BUCKET_SIZE

## 300~8300 구간을 350px 칸으로 나눠서, 칸마다 무작위 위치/종류로 아이템을 등장시킨다.
## 발판/상자 배치와는 완전히 독립적인 칸 체계이고, 아이템은 항상 ITEM_SAFE_Y(일반 점프/걷기로
## 항상 닿는 높이)에 놓이므로 장애물이 있든 없든 못 먹는 아이템이 생기지 않는다.
func _build_random_items() -> void:
	var x := ITEM_ZONE_START
	while x < ITEM_ZONE_END:
		var spawn_x: float = x + randf() * ITEM_BUCKET_SIZE
		_add_item(spawn_x, ITEM_SAFE_Y, randi() % ITEM_TYPE_COUNT)
		x += ITEM_BUCKET_SIZE

## 완결(레벨 끝) 지점 장식: finish_tile 폴더 이미지만 사용한다. 콜리전이 없는 순수 장식이라
## 위 무작위 배치와 무관하게 항상 맵 끝에 고정으로 세운다.
func _build_finish_decoration() -> void:
	for i in range(PILLAR_TEXTURES.size()):
		var px: float = 8320.0 + i * 60.0
		var pillar := Sprite2D.new()
		pillar.texture = load(PILLAR_TEXTURES[i])
		pillar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pillar.centered = true
		pillar.position = Vector2(px, GROUND_TOP_Y)
		pillar.offset = Vector2(0, -pillar.texture.get_height() / 2.0)
		add_child(pillar)

# ---------------- 공용 헬퍼 ----------------

const BOX_TEXTURES: Array[String] = [
	"res://assets/tiles/box/상자1.png",
	"res://assets/tiles/box/상자2.png",
	"res://assets/tiles/box/상자3.png",
]
const PIPE_TEXTURES: Array[String] = [
	"res://assets/tiles/pip/파이프1.png",
	"res://assets/tiles/pip/파이프3.png",
	"res://assets/tiles/pip/파이프4.png",
]
const PLATFORM_TEXTURES: Array[String] = [
	"res://assets/tiles/ground/ground_01.png",
	"res://assets/tiles/ground/ground_02.png",
	"res://assets/tiles/ground/ground_03.png",
	"res://assets/tiles/ground/ground_05.png",
	"res://assets/tiles/ground/ground_06.png",
	"res://assets/tiles/ground/ground_07.png",
	"res://assets/tiles/ground/ground_08.png",
	"res://assets/tiles/ground/ground_10.png",
]
## 완결 지점 장식: finish_tile 폴더 이미지만 사용 (decorations 폴더는 사용하지 않는다)
const PILLAR_TEXTURES: Array[String] = [
	"res://assets/tiles/finish_tile/기둥1.png",
	"res://assets/tiles/finish_tile/기둥2.png",
	"res://assets/tiles/finish_tile/기둥3.png",
]

## 매 발판마다 살짝 다른 높이를 준다 (항상 안전 범위 안).
func _row_y() -> float:
	return PLATFORM_Y_BASE + randf_range(-PLATFORM_Y_JITTER, PLATFORM_Y_JITTER)

## 지면 타일 3~4개를 옆으로 이어 붙여서 한 줄짜리 발판을 만든다.
## x = 발판 행의 왼쪽 시작점, y = 발판 윗면(플레이어가 서는 높이).
func _add_platform_row(x: float, y: float) -> void:
	var tile_count := randi_range(PLATFORM_ROW_MIN_TILES, PLATFORM_ROW_MAX_TILES)
	var cursor := x
	for i in range(tile_count):
		var tex: Texture2D = load(PLATFORM_TEXTURES[randi() % PLATFORM_TEXTURES.size()])
		var w := float(tex.get_width())
		var h := float(tex.get_height())

		var body := StaticBody2D.new()
		body.position = Vector2(cursor, y)
		body.add_to_group("platform_surface")

		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		body.add_child(sprite)

		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(w, h)
		shape.shape = rect
		shape.position = Vector2(w / 2.0, h / 2.0)
		body.add_child(shape)

		add_child(body)
		cursor += w

	_add_platform_trigger(x, y)

## 발판(top_y, 왼쪽 끝 x=row_left_x) 앞에 "여기서 점프해야 발판 위로 안전하게 착지한다"는
## x구간을 포물선 운동 공식으로 계산해서 보이지 않는 트리거 영역(Area2D)으로 깐다.
## Player.gd는 이 구역(group "platform_trigger") 안에 있을 때만 JUMP_VELOCITY_HIGH를 쓴다.
##   - t1: 점프해서 발판 높이(H)까지 올라가는 데 걸리는 시간 -> 이보다 늦게 뛰면 발판 옆면에 부딪힌다.
##   - t2: 정점을 찍고 다시 발판 높이(H)로 내려오는 시간 -> 이보다 일찍 뛰면 발판을 넘어가 버린다(착지 실패).
##   -> "지금부터 뛰면 착지에 성공하는" x구간은 [row_left_x - speed*t2, row_left_x - speed*t1] 이다.
func _add_platform_trigger(row_left_x: float, top_y: float) -> void:
	var h: float = GROUND_TOP_Y - top_y
	if h <= 0.0:
		return
	var v: float = -PLAYER_JUMP_VELOCITY_HIGH
	var disc: float = v * v - 2.0 * PLAYER_GRAVITY * h
	if disc < 0.0:
		return # 현재 발판 배치에서는 발생하지 않지만, 혹시 발판이 너무 높아지면 안전하게 무시한다.
	var sq: float = sqrt(disc)
	var t1: float = (v - sq) / PLAYER_GRAVITY
	var t2: float = (v + sq) / PLAYER_GRAVITY
	var trigger_end_x: float = row_left_x - PLAYER_FORWARD_SPEED * t1
	var trigger_start_x: float = row_left_x - PLAYER_FORWARD_SPEED * t2
	var width: float = trigger_end_x - trigger_start_x
	if width <= 0.0:
		return

	var trigger := Area2D.new()
	trigger.add_to_group("platform_trigger")
	trigger.position = Vector2((trigger_start_x + trigger_end_x) / 2.0, GROUND_TOP_Y - 100.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 220.0) # 세로로 넉넉하게 잡아 플레이어가 지면에 있을 때 항상 겹치게 한다
	shape.shape = rect
	trigger.add_child(shape)
	add_child(trigger)

func _add_enemy(x: float, y: float, enemy_type: String, patrol: float, speed: float) -> void:
	var e: CharacterBody2D = EnemyScene.instantiate()
	e.position = Vector2(x, y)
	e.enemy_type = enemy_type
	e.patrol_distance = patrol
	e.speed = speed
	add_child(e)

func _add_item(x: float, y: float, item_type: int) -> void:
	if randf() < ITEM_SKIP_CHANCE:
		return
	var i: Area2D = ItemScene.instantiate()
	i.position = Vector2(x, y)
	i.item_type = item_type
	add_child(i)

func _add_box_obstacle(x: float, tex_path: String) -> void:
	var tex: Texture2D = load(tex_path)
	var target_h := 56.0
	var scale_f := target_h / tex.get_height()

	var body := StaticBody2D.new()
	body.position = Vector2(x, GROUND_TOP_Y - target_h / 2.0)

	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(scale_f, scale_f)
	body.add_child(sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(tex.get_width() * scale_f * 0.85, target_h * 0.85)
	shape.shape = rect
	body.add_child(shape)

	add_child(body)

## 상자 장애물과 동일한 방식: 목표 높이에 맞춰 스프라이트를 스케일하고 그 크기에 맞는
## 콜리전을 붙여서, 플레이어가 뛰어넘거나 위로 올라타 설 수 있는 장애물로 만든다.
func _add_pipe_obstacle(x: float, tex_path: String) -> void:
	var tex: Texture2D = load(tex_path)
	var target_h := 60.0
	var scale_f := target_h / tex.get_height()

	var body := StaticBody2D.new()
	body.position = Vector2(x, GROUND_TOP_Y - target_h / 2.0)

	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(scale_f, scale_f)
	body.add_child(sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(tex.get_width() * scale_f * 0.85, target_h * 0.85)
	shape.shape = rect
	body.add_child(shape)

	add_child(body)
