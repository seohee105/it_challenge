extends AnimatableBody2D
## 옥수수 농장 구간의 "레일 이동" 발판. travel 만큼 왕복하며, 타이밍 맞춰 올라타야 한다.
## AnimatableBody2D + sync_to_physics 덕분에 위에 탄 CharacterBody2D가 자동으로 같이 이동한다.
## 다른 발판들과 같은 지면 타일셋을 사용해서 통일감 있게 보이도록 한다.

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

@export var travel: Vector2 = Vector2(160, 0)
@export var speed: float = 60.0

@onready var visual: Sprite2D = $Visual
@onready var collision: CollisionShape2D = $CollisionShape2D

var _start: Vector2
var _t: float = 0.0
var _dir: float = 1.0

func _ready() -> void:
	var tex: Texture2D = load(PLATFORM_TEXTURES[randi() % PLATFORM_TEXTURES.size()])
	visual.texture = tex
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var rect := RectangleShape2D.new()
	rect.size = tex.get_size()
	collision.shape = rect

	# position은 LevelBuilder가 "윗면 높이" 기준으로 넘겨준 값이므로, 타일 절반 높이만큼 내려서
	# 스프라이트/충돌 모양의 중심(center)이 실제 발판 중심에 오도록 보정한다.
	position.y += tex.get_height() / 2.0
	_start = position

func _physics_process(delta: float) -> void:
	var dist := travel.length()
	if dist <= 0.0:
		return
	_t += (speed * delta / dist) * _dir
	if _t >= 1.0:
		_t = 1.0
		_dir = -1.0
	elif _t <= 0.0:
		_t = 0.0
		_dir = 1.0
	position = _start + travel * _t
