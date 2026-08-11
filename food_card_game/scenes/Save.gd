## 저장 (오토로드) — 승리/연승 + 코인 + 카드 레벨
extends Node

const PATH := "user://save.cfg"

var wins := 0
var best_streak := 0
var streak := 0
var coins := 0
var levels := [1, 1, 1]
var char_id := "player"   # 선택된 유저 캐릭터 (전환 구조용, 기본 player)

func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		wins = int(cf.get_value("stats", "wins", 0))
		best_streak = int(cf.get_value("stats", "best_streak", 0))
		coins = int(cf.get_value("stats", "coins", 0))
		var lv = cf.get_value("stats", "levels", [1, 1, 1])
		if lv is Array and lv.size() == 3:
			levels = [int(lv[0]), int(lv[1]), int(lv[2])]
		char_id = String(cf.get_value("stats", "char_id", "player"))

func record_win(reward: int) -> void:
	wins += 1
	streak += 1
	if streak > best_streak:
		best_streak = streak
	coins += reward
	_save()

func record_loss(reward: int) -> void:
	streak = 0
	coins += reward
	_save()

func upgrade(i: int, price: int) -> bool:
	if coins < price:
		return false
	coins -= price
	levels[i] += 1
	_save()
	return true

func set_char(id: String) -> void:
	char_id = id
	_save()

func spend(n: int) -> bool:
	if coins < n:
		return false
	coins -= n
	_save()
	return true

func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("stats", "wins", wins)
	cf.set_value("stats", "best_streak", best_streak)
	cf.set_value("stats", "coins", coins)
	cf.set_value("stats", "levels", levels)
	cf.set_value("stats", "char_id", char_id)
	cf.save(PATH)
