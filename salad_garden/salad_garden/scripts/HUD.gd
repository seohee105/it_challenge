extends CanvasLayer
## 화면 상단 UI: 생명력 게이지 바, 공격/방어 아이템 보유 표시
## 화면 하단 UI: 오토런용 점프/공격 터치 버튼 (Level1.gd가 jump_pressed/attack_pressed 신호를 Player에 연결한다)

signal jump_pressed
signal attack_pressed

@onready var gauge_bar: TextureProgressBar = $Control/GaugeBar
@onready var gauge_label: Label = $Control/GaugeLabel
@onready var attack_icon: Label = $Control/AttackIcon
@onready var shield_label: Label = $Control/ShieldLabel
@onready var jump_button: Button = $JumpButton
@onready var attack_button: Button = $AttackButton

func _ready() -> void:
	GameManager.gauge_changed.connect(_on_gauge_changed)
	GameManager.attack_changed.connect(_on_attack_changed)
	GameManager.shield_changed.connect(_on_shield_changed)
	_on_gauge_changed(GameManager.current_gauge, GameManager.max_gauge)
	_on_attack_changed(GameManager.attack_charges)
	_on_shield_changed(GameManager.shield_charges)

	jump_button.button_down.connect(func() -> void: jump_pressed.emit())
	attack_button.button_down.connect(func() -> void: attack_pressed.emit())

func _on_gauge_changed(current: float, max_value: float) -> void:
	gauge_bar.max_value = max_value
	gauge_bar.value = current
	var percent: int = roundi(current / max_value * 100.0) if max_value > 0.0 else 0
	gauge_label.text = "%d%%" % percent

func _on_attack_changed(charges: int) -> void:
	attack_icon.text = "🗡 x%d" % charges

func _on_shield_changed(charges: int) -> void:
	shield_label.text = "🛡 x%d" % charges
