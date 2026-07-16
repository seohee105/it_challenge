extends Control

@onready var nickname = $MarginContainer/VBoxContainer/NicknameLabel
@onready var day = $MarginContainer/VBoxContainer/DayLabel
@onready var coin = $MarginContainer/VBoxContainer/CoinLabel


func _ready():
	nickname.text = "닉네임 : " + GameManager.player_data["nickname"]
	day.text = "DAY " + str(GameManager.player_data["day"])
	coin.text = "코인 : " + str(GameManager.player_data["coin"])
