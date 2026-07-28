## 배경음악 (오토로드) — 코드 합성 칩튠 2종(타이틀/전투) + 음소거 토글
extends Node

const RATE := 22050

var _player: AudioStreamPlayer
var _title: AudioStreamWAV
var _battle: AudioStreamWAV
var muted := false

const NOTE := {
	"C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.00, "A4": 440.00, "B4": 493.88,
	"C5": 523.25, "D5": 587.33, "E5": 659.25, "F5": 698.46, "G5": 783.99, "A5": 880.00,
	"As4": 466.16, "Ds5": 622.25, "0": 0.0,
}

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.volume_db = -9.0
	# 타이틀곡: 밝은 장조
	_title = _make_track(
		["C5", "E5", "G5", "E5", "C5", "E5", "G5", "A4", "F4", "A4", "C5", "A4", "F4", "A4", "C5", "D5",
		 "G4", "B4", "D5", "B4", "G4", "B4", "D5", "E5", "C5", "E5", "G5", "E5", "G5", "E5", "C5", "0"],
		["C4", "C4", "F4", "F4", "G4", "G4", "C4", "C4"], 0.19)
	# 전투곡: 빠르고 긴박한 단조
	_battle = _make_track(
		["A4", "A4", "C5", "A4", "E5", "0", "A4", "C5", "G4", "G4", "As4", "G4", "Ds5", "0", "G4", "As4",
		 "F4", "A4", "C5", "F5", "E5", "D5", "C5", "A4", "A4", "C5", "E5", "A5", "E5", "C5", "A4", "0"],
		["A4", "A4", "G4", "G4", "F4", "F4", "E4", "E4"], 0.15)
	play_title()

func play_title() -> void:
	_set_stream(_title)

func play_battle() -> void:
	_set_stream(_battle)

func _set_stream(s: AudioStreamWAV) -> void:
	if _player.stream == s and _player.playing:
		return
	_player.stream = s
	_player.play()

func toggle_mute() -> bool:
	muted = not muted
	_player.volume_db = -60.0 if muted else -9.0
	return muted

func _make_track(melody: Array, bass: Array, beat: float) -> AudioStreamWAV:
	var per := int(RATE * beat)
	var total := melody.size() * per
	var buf := PackedFloat32Array()
	buf.resize(total)
	for i in melody.size():
		var f: float = NOTE[melody[i]]
		var bf: float = NOTE[bass[i / 4]]
		for s in per:
			var t := float(s) / RATE
			var env: float = minf(t / 0.01, 1.0) * (1.0 - minf(t / beat, 1.0) * 0.4)
			var v := 0.0
			if f > 0.0:
				v += (1.0 if sin(TAU * f * t) >= 0.0 else -1.0) * 0.16 * env
			v += sin(TAU * bf * t) * 0.10 * env
			buf[i * per + s] = v
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = total
	w.data = data
	return w
