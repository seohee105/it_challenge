extends Node
## 게임 전역 상태 관리자 (오토로드 싱글톤)
## - 생명력 게이지 (♥️ 하트를 먹으면 최대치/현재치 증가)
## - 공격 아이템 개수 (🗡️ 먹을 때마다 공격 버튼을 누를 수 있는 횟수가 1씩 늘어남)
## - 방어막 개수 (🛡️ 먹으면 적과 부딪혀도 게이지가 안 깎이고 통과 가능)
## - 게이지가 0이 되면 보스전 입장 불가 -> 게임 종료

signal gauge_changed(current: float, max_value: float)
signal attack_changed(charges: int)
signal shield_changed(charges: int)
signal game_over

const MAX_GAUGE_DEFAULT: float = 100.0
const GAUGE_LOSS_ON_HIT: float = 20.0
const GAUGE_GAIN_ON_HEART: float = 25.0

var max_gauge: float = MAX_GAUGE_DEFAULT
var current_gauge: float = MAX_GAUGE_DEFAULT
var attack_charges: int = 0
var shield_charges: int = 0

func reset_game() -> void:
	max_gauge = MAX_GAUGE_DEFAULT
	current_gauge = MAX_GAUGE_DEFAULT
	attack_charges = 0
	shield_charges = 0
	gauge_changed.emit(current_gauge, max_gauge)
	attack_changed.emit(attack_charges)
	shield_changed.emit(shield_charges)

func gain_heart() -> void:
	# 하트 획득 -> 게이지 최대치 & 현재치 증가 (플레이 가능 시간이 늘어나는 효과)
	max_gauge += GAUGE_GAIN_ON_HEART
	current_gauge = min(current_gauge + GAUGE_GAIN_ON_HEART, max_gauge)
	gauge_changed.emit(current_gauge, max_gauge)

func gain_attack() -> void:
	attack_charges += 1
	attack_changed.emit(attack_charges)

## 공격 버튼 사용 시도: 남은 횟수가 있으면 1 소모하고 true, 없으면 false(공격 불가)
func use_attack() -> bool:
	if attack_charges > 0:
		attack_charges -= 1
		attack_changed.emit(attack_charges)
		return true
	return false

func gain_shield() -> void:
	shield_charges += 1
	shield_changed.emit(shield_charges)

func use_shield() -> bool:
	if shield_charges > 0:
		shield_charges -= 1
		shield_changed.emit(shield_charges)
		return true
	return false

func take_damage(amount: float = GAUGE_LOSS_ON_HIT) -> void:
	current_gauge = max(current_gauge - amount, 0.0)
	gauge_changed.emit(current_gauge, max_gauge)
	if current_gauge <= 0.0:
		game_over.emit()

func can_enter_boss() -> bool:
	return current_gauge > 0.0
