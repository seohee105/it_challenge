extends Node
class_name AIClient

signal analysis_succeeded(result: Dictionary)
signal analysis_failed(message: String)

@export var ai_server_url := "https://foodaicamera-ai-seohee105.onrender.com/analyze"

var _http: HTTPRequest
var _is_busy := false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 90.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func is_busy() -> bool:
	return _is_busy


func analyze_food_photo(image_path: String, bmr_kcal: float = 0.0, exercise_kcal: float = 0.0) -> void:
	if _is_busy:
		analysis_failed.emit("이미 분석 요청을 처리하고 있습니다. 잠시만 기다려주세요.")
		return

	if image_path.strip_edges().is_empty():
		analysis_failed.emit("분석할 사진을 먼저 선택해주세요.")
		return

	var file := FileAccess.open(image_path, FileAccess.READ)
	if file == null:
		analysis_failed.emit("사진 파일을 읽을 수 없습니다: " + image_path)
		return

	var image_bytes := file.get_buffer(file.get_length())
	if image_bytes.is_empty():
		analysis_failed.emit("사진 파일이 비어 있습니다.")
		return

	var boundary := "----GodotFoodAIBoundary" + str(Time.get_ticks_msec())
	var body := PackedByteArray()
	var file_name := image_path.get_file()
	var mime_type := _guess_mime_type(file_name)

	_append_form_field(body, boundary, "bmr_kcal", str(bmr_kcal))
	_append_form_field(body, boundary, "exercise_kcal", str(exercise_kcal))
	_append_text(body, "--" + boundary + "\r\n")
	_append_text(body, 'Content-Disposition: form-data; name="image"; filename="' + file_name + '"\r\n')
	_append_text(body, "Content-Type: " + mime_type + "\r\n\r\n")
	body.append_array(image_bytes)
	_append_text(body, "\r\n--" + boundary + "--\r\n")

	var headers := ["Content-Type: multipart/form-data; boundary=" + boundary]
	_is_busy = true
	var err := _http.request_raw(ai_server_url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_is_busy = false
		analysis_failed.emit(_request_error_message(err))


func _append_form_field(body: PackedByteArray, boundary: String, name: String, value: String) -> void:
	_append_text(body, "--" + boundary + "\r\n")
	_append_text(body, 'Content-Disposition: form-data; name="' + name + '"' + "\r\n\r\n")
	_append_text(body, value + "\r\n")


func _append_text(body: PackedByteArray, text: String) -> void:
	body.append_array(text.to_utf8_buffer())


func _guess_mime_type(file_name: String) -> String:
	var lower_name := file_name.to_lower()
	if lower_name.ends_with(".png"):
		return "image/png"
	if lower_name.ends_with(".webp"):
		return "image/webp"
	return "image/jpeg"


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_busy = false
	var response_text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(response_text)

	if result != HTTPRequest.RESULT_SUCCESS:
		analysis_failed.emit(_http_result_message(result))
		return

	if response_code < 200 or response_code >= 300:
		var detail := response_text
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("detail"):
			detail = str(parsed["detail"])
		analysis_failed.emit("AI 서버 오류가 발생했습니다. (" + str(response_code) + ") " + detail)
		return

	if typeof(parsed) != TYPE_DICTIONARY:
		analysis_failed.emit("AI 서버 응답을 읽을 수 없습니다.")
		return

	if not parsed.get("ok", false):
		analysis_failed.emit(str(parsed.get("message", "AI 분석에 실패했습니다.")))
		return

	analysis_succeeded.emit(parsed)


func _http_result_message(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "AI 서버에 연결할 수 없습니다. 서버 주소와 네트워크 상태를 확인해주세요."
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "네트워크 연결이 끊겼습니다. 인터넷 연결을 확인해주세요."
		HTTPRequest.RESULT_TIMEOUT:
			return "AI 서버 응답 시간이 초과되었습니다. 잠시 후 다시 시도해주세요."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "보안 연결에 실패했습니다. 서버 HTTPS 설정을 확인해주세요."
		_:
			return "사진 업로드 중 오류가 발생했습니다. 오류 코드: " + str(result)


func _request_error_message(err: int) -> String:
	match err:
		ERR_UNAVAILABLE:
			return "인터넷 연결을 사용할 수 없습니다."
		ERR_INVALID_PARAMETER:
			return "AI 서버 주소가 올바르지 않습니다."
		_:
			return "AI 서버 요청을 시작할 수 없습니다. 오류 코드: " + str(err)
