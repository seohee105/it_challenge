extends Node

# 오늘의 섭취/운동 칼로리가 바뀔 때마다(음식 기록 저장, 운동 기록 저장/삭제)
# 발생한다. HomeScene은 이 신호를 받아 목표 달성 표시와 게이지 마커를 갱신한다.
signal daily_totals_changed

# 코인을 얻었을 때(식단 기록, 운동 기록, 오늘의 목표 달성) 발생한다.
# HomeScene은 이 신호를 받아 코인 표시를 갱신하고 획득 팝업을 띄운다.
signal coins_earned(amount: int, reason: String)

# 캘린더 등 다른 화면에서 메인 홈으로 돌아올 때, 처음 "터치해 시작하기" 인트로부터
# 다시 보여주지 않고 이미 열려 있던 홈 화면 상태로 바로 돌아가기 위한 플래그.
var home_intro_shown: bool = false

# 어느 던전(fast_food/dessert/salad)에서 보스전으로 들어왔는지 기록해서,
# BossBattle 씬이 그 던전에 맞는 보스로 고정 입장하도록 하는 값.
var pending_boss_id: String = ""

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
	"today_exercise_calorie": 0,

	# 오늘의 목표 달성 코인(5개)을 이미 받았는지 확인하는 날짜. 하루에 한 번만 지급.
	"goal_reward_date": "",

	# 식단이나 운동을 하루도 빠짐없이 기록한 연속 일수. 하루라도 기록이 없으면 0으로 리셋.
	"log_streak_days": 0,

	# 밤 10시 이후 무료 던전 입장을 이미 사용한 날짜. 하루에 한 번만 무료로 입장 가능.
	"dungeon_free_play_date": ""
}

# 추가 던전 입장(하루 무료 1회를 다 쓴 뒤)에 필요한 코인. 보스전 게임오버 화면의
# "이어하기" 비용과 동일하게 맞춘 값.
const DUNGEON_REPLAY_COST := 5


func update_player_info(key: String, value):
	if player_data.has(key):
		player_data[key] = value
	else:
		print("오류 :", key, "데이터가 없습니다.")


# 마지막으로 로그인한 닉네임을 별도로 기록해서, 앱을 다시 켰을 때
# 어떤 사용자의 저장 파일(user://<nickname>.json)을 불러올지 찾기 위한 용도.
const CURRENT_USER_PATH := "user://current_user.txt"


func save_current_user(nickname: String) -> void:
	var file = FileAccess.open(CURRENT_USER_PATH, FileAccess.WRITE)
	if file:
		file.store_string(nickname)
		file.close()


# 저장된 사용자 정보가 있으면 player_data에 불러와 채우고 true를 반환한다.
func load_saved_profile() -> bool:
	if not FileAccess.file_exists(CURRENT_USER_PATH):
		return false

	var file = FileAccess.open(CURRENT_USER_PATH, FileAccess.READ)
	var nickname = file.get_as_text().strip_edges()
	file.close()

	if nickname == "" or not SaveManager.player_exists(nickname):
		return false

	var data = SaveManager.load_player(nickname)
	if data.is_empty():
		return false

	for key in data.keys():
		if player_data.has(key):
			player_data[key] = data[key]

	return true


func calculate_bmr() -> float:
	var h = player_data["height"]
	var w = player_data["weight"]
	var a = player_data["age"]
	var g = player_data["gender"]

	if g == "female":
		return (10 * w) + (6.25 * h) - (5 * a) - 161
	else:
		return (10 * w) + (6.25 * h) - (5 * a) + 5


func get_today_balance() -> float:
	var bmr = calculate_bmr()
	return player_data["today_food_calorie"] - bmr - player_data["today_exercise_calorie"]


func can_enter_dungeon() -> bool:
	var balance = get_today_balance()
	return balance >= -500 and balance <= -200


# 오늘 목표(-500~-200kcal)를 달성했으면 풀 게이지(100), 아니면 절반 게이지(50)로
# 던전에 입장한다.
func get_dungeon_start_gauge() -> float:
	if can_enter_dungeon():
		return 100.0
	else:
		return 50.0


# 던전은 밤 10시(22시) 이후에만 입장할 수 있다.
func is_dungeon_time_open() -> bool:
	var hour: int = Time.get_time_dict_from_system()["hour"]
	return hour >= 22


# 밤 10시 이후 그날의 무료 던전 입장을 아직 안 썼으면 true.
func has_free_dungeon_play_today() -> bool:
	return player_data["dungeon_free_play_date"] != Time.get_date_string_from_system()


# 오늘의 무료 던전 입장을 사용 처리한다.
func use_free_dungeon_play() -> void:
	player_data["dungeon_free_play_date"] = Time.get_date_string_from_system()
	SaveManager.save_player(player_data)


# FoodRecordStore(음식 기록)와 SessionManager(운동 기록)에서 오늘 날짜의 기록만
# 직접 다시 합산해서 player_data의 오늘 섭취/운동 칼로리를 최신 상태로 맞춘다.
# 음식/운동 기록이 저장되거나 삭제될 때마다 호출해서 실시간으로 반영한다.
func refresh_today_totals() -> void:
	var today := Time.get_date_string_from_system()

	var food_store := FoodRecordStore.new()
	var food_total := 0.0
	for record in food_store.load_records_for_date(today):
		var delta = record.get("game_delta", {})
		food_total += float(delta.get("meal_kcal", 0.0))
	player_data["today_food_calorie"] = food_total

	var exercise_total := 0.0
	for record in SessionManager.sessions:
		if record.get("date", "") == today:
			exercise_total += float(record.get("calories", 0.0))
	player_data["today_exercise_calorie"] = exercise_total

	daily_totals_changed.emit()


# 다이어트 기록(식단/운동/목표 달성)으로 코인을 지급하고, HomeScene이 코인 표시와
# 획득 팝업을 갱신하도록 신호를 보낸다.
func award_coins(amount: int, reason: String) -> void:
	if amount <= 0:
		return
	BossSave.add_coins(amount)
	coins_earned.emit(amount, reason)


# 밤 10시(22시) 이후 오늘의 목표(-500~-200kcal)를 달성한 상태로 홈 화면에 들어오면
# 하루에 한 번만 코인 5개를 지급한다.
func try_award_goal_reward() -> void:
	var hour: int = Time.get_time_dict_from_system()["hour"]
	if hour < 22:
		return

	if not can_enter_dungeon():
		return

	var today := Time.get_date_string_from_system()
	if player_data["goal_reward_date"] == today:
		return

	player_data["goal_reward_date"] = today
	SaveManager.save_player(player_data)
	award_coins(5, "오늘의 목표를 달성했어요!")


func check_new_day():

	var today = Time.get_date_string_from_system()

	if player_data["last_login_date"] == "":
		player_data["last_login_date"] = today
		return

	if player_data["last_login_date"] != today:

		# 어제 식단이나 운동을 하나라도 기록했으면 연속 기록일이 이어지고,
		# 하나도 기록하지 않았으면 연속 기록이 끊긴다.
		var logged_yesterday: bool = (
			player_data["today_food_calorie"] > 0
			or player_data["today_exercise_calorie"] > 0
		)

		if logged_yesterday:
			player_data["log_streak_days"] += 1
		else:
			player_data["log_streak_days"] = 0

		player_data["day"] += 1
		player_data["last_login_date"] = today

		player_data["today_food_calorie"] = 0
		player_data["today_exercise_calorie"] = 0

		SaveManager.save_player(player_data)

		var streak: int = player_data["log_streak_days"]

		if streak > 0 and streak % 7 == 0:
			award_coins(5, "일주일 동안 꾸준히 기록했어요!")

		if streak > 0 and streak % 30 == 0:
			award_coins(20, "한 달 동안 꾸준히 기록했어요!")

		print("새로운 하루!")
