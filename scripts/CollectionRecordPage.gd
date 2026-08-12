extends Control

signal character_play_requested(character_id: String)

# 기본 캐릭터(남/여)는 처음부터 소유. 나머지는 코인으로 구매해야 플레이할 수 있다.
const BASE_CHARACTER_IDS := ["char_01", "char_02"]
const CHARACTER_PRICE := 50

const SLOT_SIZE := Vector2(170, 170)
const CARD_SIZE := Vector2(595, 800)

# 상세 카드는 항상 다이어리 오른쪽 페이지 안에 자리잡는다 (왼쪽 페이지 = 목록 그리드).
const CARD_TARGET_POS := Vector2(820, 80)

const TEX_SLOT_NORMAL := preload("res://assets/ui/day_cell_tan.png")
const TEX_SLOT_SELECTED := preload("res://assets/ui/day_cell_selected.png")

const TEX_MALE := preload("res://assets/collection/남자캐릭터_정면.png")
const TEX_FEMALE := preload("res://assets/collection/여자캐릭터_정면.png")
const TEX_KKOBI := preload("res://assets/collection/꼬비_기본.png")
const TEX_MERONGI := preload("res://assets/collection/메롱이_기본.png")
const TEX_MUNGCHI := preload("res://assets/collection/뭉치_기본.png")

# 512x512 원본에 정면 2프레임(제자리걸음용)이 가로로 나란히 들어있다.
# 두 프레임이 같은 크롭 영역을 쓰도록 미리 여백을 포함한 통합 바운딩 박스를 계산해두면
# 프레임 전환 시 캐릭터가 흔들리지 않고 다리만 움직이는 것처럼 보인다.
const FRAME_CELL_WIDTH := 256.0
const MALE_CROP := Rect2(34, 62, 148, 216)
const FEMALE_CROP := Rect2(38, 131, 146, 214)

# 마스코트 캐릭터들은 프레임이 하나뿐이라(제자리걸음 없음) 512x512 원본에서
# 캐릭터 부분만 알파 기준으로 크롭해 사용한다.
const KKOBI_CROP := Rect2(167, 159, 136, 129)
const MERONGI_CROP := Rect2(187, 192, 141, 137)
const MUNGCHI_CROP := Rect2(164, 156, 155, 125)

const WALK_FRAME_TIME := 0.22

# 캐릭터 아트가 아직 준비되지 않은 슬롯은 자리표시자("?")로만 채운다.
const CHARACTERS := [
	{"id": "char_01", "name": "남자캐릭터", "description": "기본캐릭터(남)\n클리어를 할수록 더 많은 캐릭터를 잠금해제 할 수 있어요!"},
	{"id": "char_02", "name": "여자캐릭터", "description": "기본캐릭터(여)\n클리어를 할수록 더 많은 캐릭터를 잠금해제 할 수 있어요!"},
	{"id": "char_03", "name": "꼬비", "description": "작고 귀여운 공룡 꼬비!\n겁이 많고 서툴지만 친구를 너무 좋아해요."},
	{"id": "char_04", "name": "메롱이", "description": "멍~ 때리는 게 특기인 메롱이!\n생각은 느리지만 마음은 누구보다 착해요."},
	{"id": "char_05", "name": "뭉치", "description": "호기심 많은 뭉치!\n뭐든지 좋아하고 금방 잊어버려요.\n밥 시간은 절대 안 잊음!"},
	{"id": "char_06", "name": "캐릭터 06", "description": ""},
	{"id": "char_07", "name": "캐릭터 07", "description": ""},
	{"id": "char_08", "name": "캐릭터 08", "description": ""},
	{"id": "char_09", "name": "캐릭터 09", "description": ""},
	{"id": "char_10", "name": "캐릭터 10", "description": ""},
]

@onready var _grid: GridContainer = %CharacterGrid
@onready var _focus_layer: Control = %FocusLayer
@onready var _dim_button: Button = %DimButton
@onready var _focus_card: Control = %FocusCard
@onready var _name_label: Label = %NameLabel
@onready var _hint_label: Label = %HintLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _portrait_label: Label = %PortraitLabel
@onready var _portrait_texture: TextureRect = %PortraitTexture
@onready var _play_button: Button = %PlayButton
@onready var _close_button: Button = %CloseButton

var _slot_buttons: Dictionary = {}
var _sprite_frames: Dictionary = {}
var _current_character: Dictionary = {}
var _current_owned: bool = true
var _current_source_rect := Rect2()
var _current_frames: Array = []
var _walk_frame_index := 0
var _walk_timer: Timer
var _tween: Tween


func _ready() -> void:
	_sprite_frames = {
		"char_01": _make_walk_frames(TEX_MALE, MALE_CROP),
		"char_02": _make_walk_frames(TEX_FEMALE, FEMALE_CROP),
		"char_03": _make_single_frame(TEX_KKOBI, KKOBI_CROP),
		"char_04": _make_single_frame(TEX_MERONGI, MERONGI_CROP),
		"char_05": _make_single_frame(TEX_MUNGCHI, MUNGCHI_CROP),
	}

	_walk_timer = Timer.new()
	_walk_timer.wait_time = WALK_FRAME_TIME
	_walk_timer.timeout.connect(_on_walk_tick)
	add_child(_walk_timer)

	_dim_button.pressed.connect(_close_focus)
	_close_button.pressed.connect(_close_focus)
	_play_button.pressed.connect(_on_play_pressed)
	_build_grid()


func _make_walk_frames(tex: Texture2D, crop: Rect2) -> Array:
	var frames: Array = []
	for i in range(2):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(crop.position.x + i * FRAME_CELL_WIDTH, crop.position.y, crop.size.x, crop.size.y)
		frames.append(atlas)
	return frames


func _make_single_frame(tex: Texture2D, crop: Rect2) -> Array:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = crop
	return [atlas]


func _input(event: InputEvent) -> void:
	if _focus_layer.visible and event.is_action_pressed("ui_cancel"):
		_close_focus()


func _build_grid() -> void:
	for character in CHARACTERS:
		var slot := _make_slot(character)
		_grid.add_child(slot)
		_slot_buttons[character.id] = slot


func _make_slot(character: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = SLOT_SIZE
	button.clip_text = true
	_apply_slot_texture(button, TEX_SLOT_NORMAL)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	button.add_child(vbox)

	if _sprite_frames.has(character.id):
		var icon_rect := TextureRect.new()
		icon_rect.texture = _sprite_frames[character.id][0]
		icon_rect.custom_minimum_size = Vector2(86, 86)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vbox.add_child(icon_rect)
	else:
		var icon_label := Label.new()
		icon_label.text = "?"
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 50)
		vbox.add_child(icon_label)

	var name_label := Label.new()
	name_label.text = character.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(name_label)

	button.pressed.connect(_on_slot_pressed.bind(character, button))
	return button


func _apply_slot_texture(button: Button, tex: Texture2D) -> void:
	var box := StyleBoxTexture.new()
	box.texture = tex
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)


func _set_slot_selected(selected_id: String) -> void:
	for id in _slot_buttons.keys():
		var btn: Button = _slot_buttons[id]
		_apply_slot_texture(btn, TEX_SLOT_SELECTED if id == selected_id else TEX_SLOT_NORMAL)


func _on_slot_pressed(character: Dictionary, source_button: Button) -> void:
	if _focus_layer.visible and _current_character.get("id", "") == character.id:
		return
	_current_character = character
	# FocusCard의 position/size는 FocusLayer 기준 로컬 좌표이므로, 슬롯 버튼의
	# 전역 사각형을 FocusLayer 기준으로 변환해줘야 줌 애니메이션이 실제 슬롯
	# 위치에서 정확히 시작한다.
	var global_rect := source_button.get_global_rect()
	_current_source_rect = Rect2(global_rect.position - _focus_layer.global_position, global_rect.size)
	_set_slot_selected(character.id)
	_name_label.text = character.name
	_description_label.text = character.get("description", "")
	_update_portrait(character.id)
	_update_play_button(character.id)
	_open_focus()


func _is_base_character(character_id: String) -> bool:
	return character_id in BASE_CHARACTER_IDS


func _update_play_button(character_id: String) -> void:
	_current_owned = _is_base_character(character_id) or BossSave.owns_character(character_id)
	if _current_owned:
		_play_button.text = "PLAY"
	else:
		_play_button.text = "구매 (%d코인)" % CHARACTER_PRICE


func _update_portrait(character_id: String) -> void:
	_current_frames = _sprite_frames.get(character_id, [])
	_walk_frame_index = 0

	if _current_frames.is_empty():
		_walk_timer.stop()
		_portrait_texture.visible = false
		_portrait_label.visible = true
		_hint_label.visible = true
	else:
		_portrait_texture.texture = _current_frames[0]
		_portrait_texture.visible = true
		_portrait_label.visible = false
		_hint_label.visible = false
		if _current_frames.size() > 1:
			_walk_timer.start()


func _on_walk_tick() -> void:
	if _current_frames.is_empty():
		return
	_walk_frame_index = (_walk_frame_index + 1) % _current_frames.size()
	_portrait_texture.texture = _current_frames[_walk_frame_index]


func _open_focus() -> void:
	_focus_layer.visible = true
	_focus_card.position = _current_source_rect.position
	_focus_card.size = _current_source_rect.size
	_dim_button.modulate.a = 0.0

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_BACK)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(_focus_card, "position", CARD_TARGET_POS, 0.32)
	_tween.tween_property(_focus_card, "size", CARD_SIZE, 0.32)
	_tween.tween_property(_dim_button, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_LINEAR)


func _close_focus() -> void:
	if _current_character.is_empty():
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(_focus_card, "position", _current_source_rect.position, 0.24)
	_tween.tween_property(_focus_card, "size", _current_source_rect.size, 0.24)
	_tween.tween_property(_dim_button, "modulate:a", 0.0, 0.2)
	_tween.chain().tween_callback(_on_close_finished)


func _on_close_finished() -> void:
	_focus_layer.visible = false
	_set_slot_selected("")
	_current_character = {}
	_current_frames = []
	_walk_timer.stop()


func _on_play_pressed() -> void:
	if _current_character.is_empty():
		return

	if not _current_owned:
		if BossSave.buy_character(_current_character.id, CHARACTER_PRICE):
			_update_play_button(_current_character.id)
		return

	character_play_requested.emit(_current_character.id)
	# TODO: 런 게임 씬이 준비되면 여기서 change_scene_to_file(...) 등으로 연결한다.
