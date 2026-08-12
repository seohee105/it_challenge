## 코드로 합성하는 효과음 (에셋 불필요) — AudioStreamWAV 를 실시간 생성해 재생
## Main에서 preload 후 노드로 추가해 sfx.play("이름") 형태로 사용.
extends Node

const RATE := 22050

var _players: Array[AudioStreamPlayer] = []
var _idx := 0
var _cache := {}

func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

func play(sound: String) -> void:
	if not _cache.has(sound):
		_cache[sound] = _build(sound)
	var p := _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.stream = _cache[sound]
	p.play()

# ── 사운드 정의
func _build(sound: String) -> AudioStream:
	match sound:
		"shot":   return _tone(720, 300, 0.14, "square", 0.32, 22.0, 0.05)
		"hit":    return _tone(170, 80, 0.17, "square", 0.42, 18.0, 0.6)
		"defend": return _tone(300, 640, 0.16, "square", 0.28, 12.0)
		"heal":   return _tone(520, 900, 0.28, "sine", 0.30, 6.0)
		"hurt":   return _tone(210, 70, 0.22, "noise", 0.46, 12.0, 0.8)
		"buff":   return _tone(300, 520, 0.20, "saw", 0.24, 8.0)
		"roar":   return _tone(150, 58, 0.5, "saw", 0.5, 4.0, 0.25)
		"blip":   return _tone(600, 720, 0.06, "square", 0.24, 20.0)
		"win":    return _seq([_tone(523, 523, 0.12, "square", 0.28, 8.0),
							_tone(659, 659, 0.12, "square", 0.28, 8.0),
							_tone(784, 784, 0.22, "square", 0.28, 6.0)])
		"lose":   return _seq([_tone(392, 392, 0.14, "saw", 0.28, 8.0),
							_tone(311, 311, 0.14, "saw", 0.28, 8.0),
							_tone(208, 208, 0.32, "saw", 0.28, 6.0)])
		_:        return _tone(440, 440, 0.1, "sine", 0.25, 10.0)

# 주파수 스윕 + 파형 + 감쇠 엔벨로프로 한 음 생성
func _tone(f0: float, f1: float, dur: float, wave: String, vol: float, decay: float, noise_mix := 0.0) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var tt := float(i) / RATE
		var f: float = lerpf(f0, f1, tt / dur)
		phase += TAU * f / RATE
		var s := 0.0
		match wave:
			"sine": s = sin(phase)
			"square": s = 1.0 if sin(phase) >= 0.0 else -1.0
			"saw": s = fmod(phase / TAU, 1.0) * 2.0 - 1.0
			"noise": s = randf() * 2.0 - 1.0
		if noise_mix > 0.0:
			s = lerpf(s, randf() * 2.0 - 1.0, noise_mix)
		var atk := 0.005
		var env: float = minf(tt / atk, 1.0) * exp(-decay * tt)
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	return _wav(data)

# 여러 음을 이어붙임
func _seq(segments: Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	for seg in segments:
		data.append_array(seg.data)
	return _wav(data)

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
