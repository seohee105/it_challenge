extends Node2D

@onready var life_gauge: TextureProgressBar = $CanvasLayer/GaugeUI/LifeGauge
@onready var game_over_popup: Control = $CanvasLayer/GameOverPopup
@onready var game_start_popup: Control = $CanvasLayer/GameStartPopup
@onready var player = $Player
@onready var boss_door_trigger: Area2D = $BossDoorTrigger

const BOSS_BATTLE_SCENE: String = "res://scenes/boss_battle/BossBattle.tscn"


# ================================
# 오디오
# ================================

@onready var dessert_audio: AudioStreamPlayer = $DessertKingdomAudio
@onready var item_get_audio: AudioStreamPlayer = $ItemGetAudio
@onready var heart_fever_audio: AudioStreamPlayer = $HeartFeverAudio
@onready var slash_audio: AudioStreamPlayer = $SlashAudio
@onready var shield_audio: AudioStreamPlayer = $ShieldAudio
@onready var jump_audio: AudioStreamPlayer = $JumpAudio
@onready var stomp_audio: AudioStreamPlayer = $StompAudio

# 마카롱 통통 효과음
@onready var macaroon_bounce_audio: AudioStreamPlayer = $MacaroonBounceAudio

# 슬라임 이동 효과음
@onready var slime_move_audio: AudioStreamPlayer = $SlimeMoveAudio

# 도넛 이동 효과음
@onready var donut_step_audio: AudioStreamPlayer = $DonutMonsterStepAudio

# 캔디 박쥐 날갯짓 효과음
@onready var candy_fly_audio: AudioStreamPlayer = $CandyMonsterFlyAudio

# ================================
# 마카롱 효과음 Marker
# ================================

@onready var macaroon_sound_marker: Marker2D = $MacaroonSoundMarker
@onready var macaroon_sound_end_marker: Marker2D = $MacaroonSoundEndMarker



# ================================
# 생명력
# ================================

var max_life: float = 100.0
var life: float = 100.0

# 1초에 1씩 감소
var drain_per_second: float = 1.0

# 시작 연출 동안은 false
var game_running: bool = false


# ================================
# 마카롱 효과음 상태
# ================================

var macaroon_sound_started: bool = false
var macaroon_sound_finished: bool = false
var macaroon_sound_loop_running: bool = false


# ================================
# 슬라임 효과음 상태
# ================================

var slime_sound_active: bool = false

# 도넛 효과음 상태
var donut_sound_active: bool = false

# 캔디 박쥐 효과음 상태
var candy_fly_sound_active: bool = false

# ================================
# 시작
# ================================

func _ready() -> void:
	# 오늘의 칼로리 목표(섭취 - 기초대사량 - 운동 소모)를 달성했으면 풀 게이지,
	# 아니면 절반 게이지로 던전에 입장한다.
	life = GameManager.get_dungeon_start_gauge()
	max_life = 100.0

	life_gauge.min_value = 0.0
	life_gauge.max_value = max_life
	life_gauge.value = life

	boss_door_trigger.body_entered.connect(_on_boss_door_entered)

	# 처음에는 Game Over 팝업 숨기기
	game_over_popup.visible = false

	# 시작할 때 플레이어 정지
	player.can_move = false

	# 시작 전에 반복 효과음 정지
	macaroon_bounce_audio.stop()
	slime_move_audio.stop()
	donut_step_audio.stop()
	candy_fly_audio.stop()
	
	print("DessertKingdom 시작")
	print("초기 게이지: ", life)

	# READY → GAME START!
	await start_game_sequence()


# ================================
# 게임 시작 연출
# ================================

func start_game_sequence() -> void:
	game_running = false
	player.can_move = false

	# GameStartPopup 연출
	await game_start_popup.play_start_sequence()

	# 실제 게임 시작
	game_running = true
	player.can_move = true

	# BGM 시작
	dessert_audio.play()

	print("게임 시작!")


# ================================
# 게임 진행
# ================================

func _process(delta: float) -> void:
	if not game_running:
		return
	# =========================================
	# 캔디 박쥐 날갯짓 효과음 반복
	# =========================================
	if candy_fly_sound_active:
		if not candy_fly_audio.playing:
			candy_fly_audio.play()
			
	# =========================================
	# 도넛 몬스터 발걸음 효과음 반복
	# =========================================
	if donut_sound_active:
		if not donut_step_audio.playing:
			donut_step_audio.play()

	# =========================================
	# 마카롱 통통 효과음 시작
	# =========================================

	if (
		not macaroon_sound_started
		and not macaroon_sound_finished
		and player.global_position.x >= macaroon_sound_marker.global_position.x
	):
		macaroon_sound_started = true

		print("마카롱 효과음 구간 시작")

		if not macaroon_sound_loop_running:
			start_macaroon_bounce_sound()


	# =========================================
	# 마카롱 통통 효과음 종료
	# =========================================

	if (
		macaroon_sound_started
		and player.global_position.x >= macaroon_sound_end_marker.global_position.x
	):
		stop_macaroon_bounce_sound()

		print("마카롱 효과음 구간 종료")


	# =========================================
	# 슬라임 이동 효과음 반복
	# =========================================
	# SlimeSoundZone 안에 있는 동안
	# 효과음이 끝나면 다시 재생
	# =========================================

	if slime_sound_active:
		if not slime_move_audio.playing:
			slime_move_audio.play()


	# =========================================
	# 시간에 따라 게이지 감소
	# =========================================

	life -= drain_per_second * delta
	life = clampf(life, 0.0, max_life)

	life_gauge.value = life


	# =========================================
	# 게이지 0 → Game Over
	# =========================================

	if life <= 0.0:
		game_over()
		return


	# =========================================
	# 낙사 → Game Over
	# =========================================

	if player.global_position.y > 1200.0:
		game_over()


# ================================
# 마카롱 통통 효과음 반복
# ================================

func start_macaroon_bounce_sound() -> void:
	if macaroon_sound_loop_running:
		return

	macaroon_sound_loop_running = true

	while (
		macaroon_sound_started
		and not macaroon_sound_finished
		and game_running
	):
		macaroon_bounce_audio.play()

		await macaroon_bounce_audio.finished

		if (
			not macaroon_sound_started
			or macaroon_sound_finished
			or not game_running
		):
			break

		await get_tree().create_timer(0.25).timeout

	macaroon_sound_loop_running = false


# ================================
# 마카롱 효과음 종료
# ================================

func stop_macaroon_bounce_sound() -> void:
	macaroon_sound_started = false
	macaroon_sound_finished = true

	if macaroon_bounce_audio.playing:
		macaroon_bounce_audio.stop()


# ================================
# 슬라임 이동 효과음 시작
# SlimeSoundZone에서 호출
# ================================

func start_slime_move_sound() -> void:
	if not game_running:
		return

	# 이미 다른 Zone에서 재생 중이면 중복 실행 방지
	if slime_sound_active:
		return

	slime_sound_active = true

	# Zone에 들어오자마자 바로 재생
	slime_move_audio.play()

	print("슬라임 효과음 시작")


# ================================
# 슬라임 이동 효과음 종료
# SlimeSoundZone에서 호출
# ================================

func stop_slime_move_sound() -> void:
	if not slime_sound_active:
		return

	slime_sound_active = false

	slime_move_audio.stop()

	print("슬라임 효과음 종료")

# ================================
# 도넛 몬스터 발걸음 효과음 시작
# DonutSoundZone에서 호출
# ================================

func start_donut_step_sound() -> void:
	if not game_running:
		return

	if donut_sound_active:
		return

	donut_sound_active = true

	# 구간에 들어오자마자 재생
	donut_step_audio.play()

	print("도넛 발걸음 효과음 시작")


# ================================
# 도넛 몬스터 발걸음 효과음 종료
# DonutSoundZone에서 호출
# ================================

func stop_donut_step_sound() -> void:
	if not donut_sound_active:
		return

	donut_sound_active = false

	donut_step_audio.stop()

	print("도넛 발걸음 효과음 종료")


# ================================
# 캔디 박쥐 날갯짓 효과음 시작
# ================================

func start_candy_fly_sound() -> void:
	if not game_running:
		return

	if candy_fly_sound_active:
		return

	candy_fly_sound_active = true

	candy_fly_audio.play()

	print("캔디 박쥐 Fly 효과음 시작")


# ================================
# 캔디 박쥐 날갯짓 효과음 종료
# ================================

func stop_candy_fly_sound() -> void:
	if not candy_fly_sound_active:
		return

	candy_fly_sound_active = false

	candy_fly_audio.stop()

	print("캔디 박쥐 Fly 효과음 종료")
	
	
# ================================
# 회복
# ================================

func heal(amount: float) -> void:
	if not game_running:
		return

	life += amount
	life = clampf(life, 0.0, max_life)

	life_gauge.value = life

	# 하트 피버 문구 표시
	player.show_heart_effect()

	print("하트 획득! 현재 게이지: ", life)


# ================================
# 피해
# ================================

func take_damage(amount: float) -> void:
	print("take_damage 실행됨! 피해량: ", amount)

	if not game_running:
		print("game_running이 false라서 피해 취소")
		return

	life -= amount
	life = clampf(life, 0.0, max_life)

	life_gauge.value = life
	
	# 피격 문구 표시
	if player.has_method("show_damage_effect"):
		player.show_damage_effect(amount)
		
	print("적에게 맞음! 현재 게이지: %.1f" % life)

	if life <= 0.0:
		game_over()


# ================================
# 보스 문
# ================================

func _on_boss_door_entered(body: Node2D) -> void:
	if body.name != "Player":
		return

	if not game_running:
		return

	GameManager.pending_boss_id = "dessert"

	var error := get_tree().change_scene_to_file(BOSS_BATTLE_SCENE)
	if error != OK:
		push_error("보스전 씬을 열지 못했습니다: " + BOSS_BATTLE_SCENE)


# ================================
# Game Over
# ================================

func game_over() -> void:
	if not game_running:
		return

	game_running = false

	life = 0.0
	life_gauge.value = 0.0

	# 캐릭터 정지
	player.can_move = false
 	
	# 디저트 왕국 BGM 정지
	if dessert_audio.playing:
		dessert_audio.stop()

	# =========================================
	# 반복 효과음 정지
	# =========================================

	macaroon_sound_started = false
	slime_sound_active = false
	donut_sound_active = false
	candy_fly_sound_active = false
	
	if macaroon_bounce_audio.playing:
		macaroon_bounce_audio.stop()

	if slime_move_audio.playing:
		slime_move_audio.stop()
	
	if donut_step_audio.playing:
		donut_step_audio.stop()
	
	if candy_fly_audio.playing:
		candy_fly_audio.stop()
		
	print("GAME OVER")

	# Game Over 팝업 표시
	if game_over_popup.has_method("show_game_over"):
		game_over_popup.show_game_over()
	else:
		game_over_popup.visible = true

# ================================
# 효과음
# ================================

func play_item_get_sound() -> void:
	item_get_audio.play()


func play_heart_fever_sound() -> void:
	heart_fever_audio.play()


func play_slash_sound() -> void:
	slash_audio.play()


func play_shield_sound() -> void:
	shield_audio.play()


func play_jump_sound() -> void:
	jump_audio.play()


func play_stomp_sound() -> void:
	stomp_audio.play()
