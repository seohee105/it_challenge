extends Node

signal food_analyzed(result: Dictionary)
signal food_analyze_failed(message: String)

@export var ai_server_url := "http://127.0.0.1:8000/analyze"

var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func analyze_food_photo(image_path: String, bmr_kcal: float = 0.0, exercise_kcal: float = 0.0) -> void:
	var file := FileAccess.open(image_path, FileAccess.READ)
	if file == null:
		food_analyze_failed.emit("Image file not found: " + image_path)
		return

	var image_bytes := file.get_buffer(file.get_length())
	var file_name := image_path.get_file() # 파일명 자동 추출
	
	var boundary := "----GodotFoodAIBoundary"
	var body := PackedByteArray()

	# text 대신 바이너리 버퍼로 안전하게 추가하는 방식 적용
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array(('Content-Disposition: form-data; name="bmr_kcal"' + "\r\n\r\n").to_utf8_buffer())
	body.append_array((str(bmr_kcal) + "\r\n").to_utf8_buffer())
	
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array(('Content-Disposition: form-data; name="exercise_kcal"' + "\r\n\r\n").to_utf8_buffer())
	body.append_array((str(exercise_kcal) + "\r\n").to_utf8_buffer())
	
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array(('Content-Disposition: form-data; name="image"; filename="' + file_name + '"\r\n').to_utf8_buffer())
	body.append_array(("Content-Type: application/octet-stream\r\n\r\n").to_utf8_buffer())
	
	# 깨지지 않은 온전한 이미지 바이너리 데이터 주입
	body.append_array(image_bytes)
	
	body.append_array(("\r\n--" + boundary + "--\r\n").to_utf8_buffer())

	var headers := ["Content-Type: multipart/form-data; boundary=" + boundary]
	var err := _http.request_raw(ai_server_url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		food_analyze_failed.emit("HTTP request failed: " + str(err))


func _append_text(body: PackedByteArray, text: String) -> void:
	body.append_array(text.to_utf8_buffer())


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		food_analyze_failed.emit("AI server error: " + str(response_code))
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		food_analyze_failed.emit("Invalid AI response")
		return

	food_analyzed.emit(parsed)


func _on_button_pressed() -> void:
	print("분석 버튼 클릭됨! 사진 분석을 요청합니다...")
	
	# 테스트할 실제 이미지 경로를 적어줍니다. 
	# 예: 파이썬 프로젝트 폴더 내 test_images 폴더 안의 이미지
	var test_image = "res://test_images/김치찌개.jpg"
	# 코드에 있는 함수를 호출합니다 (칼로리 기본값은 0.0으로 설정)
	analyze_food_photo(test_image, 0.0, 0.0)
	
# 이 함수는 고도가 처음 켜질 때 실행됩니다.
# 기존 _ready() 함수 밑에 이 두 줄을 추가하거나, 아래처럼 새로 적어주셔도 됩니다.
func _init() -> void:
	# 내가 보낸 신호를 내가 직접 받아서 처리하도록 연결합니다.
	food_analyzed.connect(_on_food_analyzed)
	food_analyze_failed.connect(_on_food_analyze_failed)

# AI 분석이 성공했을 때 실행되는 함수 (새로운 서버 응답 구조 반영)
func _on_food_analyzed(result: Dictionary) -> void:
	print("--- AI 분석 성공! ---")
	print("서버 응답 전체 데이터: ", result)
	
	# 1. 서버가 정상적으로 처리를 완료했는지 확인
	if result.get("ok", false) == false:
		print("서버 응답은 왔으나 내부 처리에 실패했습니다.")
		return
		
	# 2. 게임에 반영할 영양소 및 칼로리 데이터 추출 (game_delta 데이터 접근)
	if result.has("game_delta"):
		var game_delta = result["game_delta"]
		
		var meal_kcal = game_delta.get("meal_kcal", 0.0)
		var net_kcal = game_delta.get("net_kcal", 0.0)
		var food_count = game_delta.get("food_count", 0.0)
		
		# 탄단지 및 나트륨 세부 정보 추출
		var macros = game_delta.get("macros", {})
		var carb = macros.get("carb_g", 0.0)
		var protein = macros.get("protein_g", 0.0)
		var fat = macros.get("fat_g", 0.0)
		var sodium = macros.get("sodium_mg", 0.0)
		
		print("======== [게임 변수 반영 데이터] ========")
		print("검출된 음식 수: ", food_count)
		print("이번 식사 칼로리: ", meal_kcal, " kcal")
		print("탄수화물: ", carb, "g | 단백질: ", protein, "g | 지방: ", fat, "g")
		print("나트륨: ", sodium, "mg")
		print("========================================")
		
		# 💡 만약 음식을 인식하지 못해 0g 일 때의 예외 처리
		if food_count == 0:
			print("알림: 사진에서 음식을 인식하지 못했거나 빈 접시입니다.")
		
		# 🎮 [여기에 게임 로직 변수를 대입하세요!]
		# 예시: 
		# PlayerStats.hp += meal_kcal * 0.1
		# PlayerStats.protein_point += protein
		
	else:
		print("오류: 응답에 game_delta 키가 존재하지 않습니다.")

# AI 분석이 실패했을 때 실행되는 함수
func _on_food_analyze_failed(message: String) -> void:
	print("--- AI 분석 실패 ---")
	print("에러 사유: ", message)
