extends Control

@export var ai_server_url := "https://foodaicamera-ai-seohee105.onrender.com/analyze"
@export var bmr_kcal := 0.0
@export var exercise_kcal := 0.0

@onready var _ai_client: AIClient = $AIClient
@onready var _camera_manager: CameraManager = $CameraManager
@onready var _ui: UIManager = $UIManager
@onready var _camera_button: Button = %CameraButton
@onready var _gallery_button: Button = %GalleryButton
@onready var _analyze_button: Button = %AnalyzeButton

# 다이어리 임베드 페이지(FoodRecordPage)처럼 이 화면 자체를 벗어나는 이동 버튼을
# 아예 빼버린 변형도 있으므로, 있을 때만 찾아서 연결한다.
@onready var _home_button: Button = get_node_or_null("%HomeButton")

var _selected_image_path := ""
var last_game_delta: Dictionary = {}
var last_saved_record: Dictionary = {}
var _warmup_http: HTTPRequest
var _record_store := FoodRecordStore.new()


func _ready() -> void:
	_ai_client.ai_server_url = ai_server_url
	_camera_button.pressed.connect(_on_camera_pressed)
	_gallery_button.pressed.connect(_on_gallery_pressed)
	_analyze_button.pressed.connect(_on_analyze_pressed)
	if _home_button:
		_home_button.pressed.connect(_on_home_pressed)

	_camera_manager.image_selected.connect(_on_image_selected)
	_camera_manager.image_cancelled.connect(_on_image_cancelled)
	_camera_manager.image_failed.connect(_on_image_failed)
	_ai_client.analysis_succeeded.connect(_on_analysis_succeeded)
	_ai_client.analysis_failed.connect(_on_analysis_failed)

	_warmup_ai_server()


# Render 무료 플랜은 일정 시간 요청이 없으면 서버가 잠들어 첫 요청이 30~60초
# 걸리거나 502를 반환할 수 있다. 앱을 켜자마자 /health를 미리 찔러 두면
# 사용자가 사진을 고르고 Analyze를 누를 때쯤엔 서버가 이미 깨어있을 확률이 높다.
func _warmup_ai_server() -> void:
	var health_url := ai_server_url.replace("/analyze", "/health")
	_warmup_http = HTTPRequest.new()
	_warmup_http.timeout = 90.0
	add_child(_warmup_http)
	_warmup_http.request_completed.connect(_on_warmup_completed)
	_warmup_http.request(health_url)


func _on_warmup_completed(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_warmup_http.queue_free()
	_warmup_http = null


func _on_camera_pressed() -> void:
	_ui.set_status("카메라를 여는 중입니다...")
	_camera_manager.open_camera()


func _on_gallery_pressed() -> void:
	_ui.set_status("갤러리를 여는 중입니다...")
	_camera_manager.open_gallery()


func _on_home_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")


func _on_analyze_pressed() -> void:
	if _selected_image_path.is_empty():
		_ui.show_error("분석할 사진을 먼저 촬영하거나 선택해주세요.")
		return
	_ui.show_analyzing()
	_ai_client.analyze_food_photo(_selected_image_path, bmr_kcal, exercise_kcal)


func _on_image_selected(image_path: String, _source: String) -> void:
	_selected_image_path = image_path
	_ui.show_selected_image(image_path)


func _on_image_cancelled(_source: String, message: String) -> void:
	_ui.show_error(message)


func _on_image_failed(_source: String, message: String) -> void:
	_ui.show_error(message)


func _on_analysis_succeeded(result: Dictionary) -> void:
	last_game_delta = result.get("game_delta", {})
	last_saved_record = _record_store.save_record(_selected_image_path, result)
	GameManager.refresh_today_totals()
	GameManager.award_coins(1, "식단을 기록했어요!")
	_ui.show_result(result)
	_apply_game_delta(last_game_delta)


func _on_analysis_failed(message: String) -> void:
	_ui.show_error(message)


func _apply_game_delta(game_delta: Dictionary) -> void:
	# PlayerStats 같은 게임 상태가 생기면 여기에서 바로 적용할 수 있습니다.
	# 예: PlayerStats.apply_meal_delta(game_delta)
	pass
