extends Control

@onready var nickname = $NicknameLineEdit


func _on_login_button_pressed() -> void:
	print('로그인  버튼 눌림')

	var name = nickname.text.strip_edges()

	if name == "":
		print("닉네임을 입력하세요.")
		return

	if SaveManager.player_exists(name):

		GameManager.player_data = SaveManager.load_player(name)
		GameManager.check_new_day()


		print("불러오기 성공!")

		get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")

	else:
		print("존재하지 않는 캐릭터입니다.")


func _on_create_button_pressed() -> void:
	print('새로운 탐험가 버튼 눌림')

	get_tree().change_scene_to_file("res://scenes/CreateCharacterScene.tscn")
