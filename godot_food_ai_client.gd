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
	var boundary := "----GodotFoodAIBoundary"
	var body := PackedByteArray()

	_append_text(body, "--" + boundary + "\r\n")
	_append_text(body, 'Content-Disposition: form-data; name="bmr_kcal"' + "\r\n\r\n")
	_append_text(body, str(bmr_kcal) + "\r\n")
	_append_text(body, "--" + boundary + "\r\n")
	_append_text(body, 'Content-Disposition: form-data; name="exercise_kcal"' + "\r\n\r\n")
	_append_text(body, str(exercise_kcal) + "\r\n")
	_append_text(body, "--" + boundary + "\r\n")
	_append_text(body, 'Content-Disposition: form-data; name="image"; filename="food.jpg"' + "\r\n")
	_append_text(body, "Content-Type: image/jpeg\r\n\r\n")
	body.append_array(image_bytes)
	_append_text(body, "\r\n--" + boundary + "--\r\n")

	var headers := ["Content-Type: multipart/form-data; boundary=" + boundary]
	var err := _http.request_raw(ai_server_url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		food_analyze_failed.emit("HTTP request failed: " + str(err))


func _append_text(body: PackedByteArray, text: String) -> void:
	body.append_array(text.to_utf8_buffer())


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var response_text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(response_text)

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var detail := response_text
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("detail"):
			detail = str(parsed["detail"])
		food_analyze_failed.emit("AI server error: " + str(response_code) + " - " + detail)
		return

	if typeof(parsed) != TYPE_DICTIONARY:
		food_analyze_failed.emit("Invalid AI response: " + response_text)
		return

	food_analyzed.emit(parsed)
