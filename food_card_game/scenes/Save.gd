## 저장 (오토로드) — 승리/연승 + 코인 + 카드 레벨
extends Node

const PATH := "user://save.cfg"

var wins := 0
var best_streak := 0
var streak := 0
var coins := 0
var levels := [1, 1, 1]

func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		wins = int(cf.get_value("stats", "wins", 0))
		best_streak = int(cf.get_value("stats", "best_streak", 0))
		coins = int(cf.get_value("stats", "coins", 0))
		var lv = cf.get_value("stats", "levels", [1, 1, 1])
		if lv is Array and lv.size() == 3:
			levels = [int(lv[0]), int(lv[1]), int(lv[2])]

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

func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("stats", "wins", wins)
	cf.set_value("stats", "best_streak", best_streak)
	cf.set_value("stats", "coins", coins)
	cf.set_value("stats", "levels", levels)
	cf.save(PATH)
