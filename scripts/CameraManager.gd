extends Node
class_name CameraManager

signal image_selected(image_path: String, source: String)
signal image_cancelled(source: String, message: String)
signal image_failed(source: String, message: String)

var _plugin: Object


func _ready() -> void:
	if Engine.has_singleton("FoodPhotoPicker"):
		_plugin = Engine.get_singleton("FoodPhotoPicker")
		_connect_plugin_signal("photo_selected", _on_photo_selected)
		_connect_plugin_signal("photo_cancelled", _on_photo_cancelled)
		_connect_plugin_signal("photo_failed", _on_photo_failed)


func open_camera() -> void:
	if not _ensure_android_plugin("camera"):
		return
	_plugin.takePhoto()


func open_gallery() -> void:
	if not _ensure_android_plugin("gallery"):
		return
	_plugin.pickPhoto()


func _ensure_android_plugin(source: String) -> bool:
	if _plugin != null:
		return true
	if OS.get_name() != "Android":
		image_failed.emit(source, "카메라와 갤러리는 Android 빌드에서 사용할 수 있습니다.")
	else:
		image_failed.emit(source, "Android 사진 플러그인을 찾을 수 없습니다. FoodPhotoPicker AAR와 GDAP 설정을 확인해주세요.")
	return false


func _connect_plugin_signal(signal_name: StringName, target: Callable) -> void:
	if _plugin != null and _plugin.has_signal(signal_name) and not _plugin.is_connected(signal_name, target):
		_plugin.connect(signal_name, target)


func _on_photo_selected(path: String, source: String) -> void:
	if path.strip_edges().is_empty():
		image_cancelled.emit(source, "사진 선택이 취소되었습니다.")
		return
	image_selected.emit(path, source)


func _on_photo_cancelled(source: String) -> void:
	var action := "촬영" if source == "camera" else "선택"
	image_cancelled.emit(source, "사진 " + action + "이 취소되었습니다.")


func _on_photo_failed(source: String, message: String) -> void:
	image_failed.emit(source, message)
