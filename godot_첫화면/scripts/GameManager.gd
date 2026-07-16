extends Node

var player_data = {
	"nickname": "",
	"gender": "",
	"age": 20,
	"height": 160.0,
	"weight": 50.0,

	"coin": 0,
	"day": 1,
	
	"last_login_date": "",

	"today_food_calorie": 0,
	"today_exercise_calorie": 0
}


func update_player_info(key: String, value):
	if player_data.has(key):
		player_data[key] = value
	else:
		print("오류 :", key, "데이터가 없습니다.")


func calculate_bmr() -> float:
	var h = player_data["height"]
	var w = player_data["weight"]
	var a = player_data["age"]
	var g = player_data["gender"]

	if g == "여성":
		return (10 * w) + (6.25 * h) - (5 * a) - 161
	else:
		return (10 * w) + (6.25 * h) - (5 * a) + 5


func get_today_balance() -> float:
	var bmr = calculate_bmr()
	return player_data["today_food_calorie"] - bmr - player_data["today_exercise_calorie"]


func can_enter_dungeon() -> bool:
	var balance = get_today_balance()
	return balance >= -500 and balance <= -200
	

	
func check_new_day():

	var today = Time.get_date_string_from_system()

	if player_data["last_login_date"] == "":
		player_data["last_login_date"] = today
		return

	if player_data["last_login_date"] != today:

		player_data["day"] += 1
		player_data["last_login_date"] = today

		player_data["today_food_calorie"] = 0
		player_data["today_exercise_calorie"] = 0

		SaveManager.save_player(player_data)

		print("새로운 하루!")
