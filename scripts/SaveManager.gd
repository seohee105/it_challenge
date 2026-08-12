extends Node


func save_player(player_data: Dictionary) -> void:
	var nickname = player_data["nickname"]

	if nickname.strip_edges() == "":
		return

	var file = FileAccess.open("user://" + nickname + ".json", FileAccess.WRITE)

	if file:
		file.store_string(JSON.stringify(player_data))
		file.close()


func player_exists(nickname: String) -> bool:
	return FileAccess.file_exists("user://" + nickname + ".json")


func load_player(nickname: String) -> Dictionary:

	if !player_exists(nickname):
		return {}

	var file = FileAccess.open("user://" + nickname + ".json", FileAccess.READ)

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()

	if json.parse(text) == OK:
		return json.data

	return {}
