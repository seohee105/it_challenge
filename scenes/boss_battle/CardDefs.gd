## 카드 정의 + 레벨 스케일링 (Main / Title 공용)
extends RefCounted

const MAX_LV := 5
const CLEAR_COIN := 10    # 던전(보스) 클리어 보상
const TRY_COIN := 3       # 패배 위로 보상 (클리어 보상보다 낮게)

# 기본 스탯 + 레벨당 성장치
const LIST := [
	{ "name": "슈가 러시", "macro": "carb",    "spr": "candy",  "color": "f4a7c0", "kind": "multi",  "sub": "빠른 연속 공격",
		"dmg": 60, "dmg_up": 12, "cooldown": 6.0, "cd_up": 0.3, "cd_min": 4.5 },
	{ "name": "프로틴 샷", "macro": "protein", "spr": "shaker", "color": "6fa8dc", "kind": "single", "sub": "강력한 한 방",
		"dmg": 250, "dmg_up": 45, "cooldown": 8.0, "cd_up": 0.4, "cd_min": 6.0 },
	{ "name": "뱃살 쿵",   "macro": "fat",     "spr": "shield", "color": "5bb87a", "kind": "guard",  "sub": "통통 방어",
		"reduce": 0.7, "dur": 4.0, "dur_up": 0.6, "cooldown": 12.0, "cd_up": 0.6, "cd_min": 8.0 },
]

static func eff_dmg(i: int, lv: int) -> int:
	return int(LIST[i].dmg) + (lv - 1) * int(LIST[i].dmg_up)

static func eff_cd(i: int, lv: int) -> float:
	return max(float(LIST[i].cd_min), float(LIST[i].cooldown) - (lv - 1) * float(LIST[i].cd_up))

static func eff_dur(i: int, lv: int) -> float:
	return float(LIST[i].get("dur", 0.0)) + (lv - 1) * float(LIST[i].get("dur_up", 0.0))

# 다음 레벨 강화 비용 (lv → lv+1). 레벨 1은 10코인, 레벨이 하나 오를 때마다 5코인씩 증가.
static func cost(lv: int) -> int:
	return 10 + (lv - 1) * 5

# 카드 표시용 스탯 3칸
static func stats(i: int, lv: int) -> Array:
	var c: Dictionary = LIST[i]
	match String(c.kind):
		"multi":
			return [["공격력", str(eff_dmg(i, lv))], ["타격", "3~5회"], ["쿨타임", "%.1f초" % eff_cd(i, lv)]]
		"single":
			return [["공격력", str(eff_dmg(i, lv))], ["타입", "원거리"], ["쿨타임", "%.1f초" % eff_cd(i, lv)]]
		"guard":
			return [["피해감소", "70%"], ["지속", "%.1f초" % eff_dur(i, lv)], ["쿨타임", "%.1f초" % eff_cd(i, lv)]]
	return []
