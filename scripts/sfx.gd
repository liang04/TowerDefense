## 音频管理
##
## 优先播放 assets/audio 下的真实音频，缺文件时回退到程序合成音（"哔"声），
## 因此放进文件即生效、不放也能正常出声。文件以"直接从磁盘载入"方式加载，
## 绕过 Godot 导入系统（与项目里 PNG/SVG 的加载方式一致）。
##
## 约定：
##   音效：assets/audio/sfx/<name>.ogg / .mp3 / .wav   （name 同请求名）
##         shoot / hit / kill / leak / wave / upgrade / sell / win / game_over
##   音乐：assets/audio/bgm/theme.ogg / .mp3 / .wav     （循环播放）
extends Node

const MIX_RATE := 22050
const SFX_DIR := "res://assets/audio/sfx/"
const BGM_DIR := "res://assets/audio/bgm/"
const SFX_VOLUME_DB := -8.0
const BGM_VOLUME_DB := -14.0

## 合成音回退参数（无音效文件时使用）
var _profiles: Dictionary = {
	"shoot": {"frequency": 760.0, "duration": 0.055, "volume": 0.28},
	"hit": {"frequency": 360.0, "duration": 0.07, "volume": 0.22},
	"kill": {"frequency": 920.0, "duration": 0.11, "volume": 0.24},
	"leak": {"frequency": 150.0, "duration": 0.18, "volume": 0.3},
	"wave": {"frequency": 520.0, "duration": 0.16, "volume": 0.22},
	"upgrade": {"frequency": 1040.0, "duration": 0.13, "volume": 0.24},
	"sell": {"frequency": 300.0, "duration": 0.1, "volume": 0.2},
	"win": {"frequency": 880.0, "duration": 0.28, "volume": 0.26},
	"game_over": {"frequency": 95.0, "duration": 0.32, "volume": 0.32},
}

var _active_players: Array[AudioStreamPlayer] = []
## name -> AudioStream（真实文件或合成音，构建一次后复用）；null 表示无声
var _stream_cache: Dictionary = {}
var _bgm_player: AudioStreamPlayer = null

func _ready() -> void:
	GameManager.sfx_requested.connect(_on_sfx_requested)
	_start_bgm()

## ---- 音效 ----

func _on_sfx_requested(sfx_name: String) -> void:
	var stream := _get_sfx_stream(sfx_name)
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = SFX_VOLUME_DB
	add_child(player)
	_active_players.append(player)
	player.finished.connect(func() -> void:
		_active_players.erase(player)
		player.queue_free()
	)
	player.play()

## 取音效流：优先真实文件，否则回退到合成音；结果缓存复用
func _get_sfx_stream(sfx_name: String) -> AudioStream:
	if _stream_cache.has(sfx_name):
		return _stream_cache[sfx_name]

	var stream := _load_audio_file(SFX_DIR + sfx_name)
	if stream == null:
		stream = _tone_for(sfx_name)
	_stream_cache[sfx_name] = stream
	return stream

func _tone_for(sfx_name: String) -> AudioStream:
	if not (sfx_name in _profiles):
		return null
	var profile: Dictionary = _profiles[sfx_name]
	return _make_tone(
		float(profile["frequency"]),
		float(profile["duration"]),
		float(profile["volume"])
	)

## ---- 背景音乐 ----

func _start_bgm() -> void:
	var stream := _load_audio_file(BGM_DIR + "theme")
	if stream == null:
		return

	# 设为循环
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.stream = stream
	_bgm_player.volume_db = BGM_VOLUME_DB
	add_child(_bgm_player)
	_bgm_player.play()

## ---- 文件加载（绕过导入系统）----

## 给定不含扩展名的基础路径，依次尝试 .ogg / .mp3 / .wav；都没有返回 null
func _load_audio_file(base_path: String) -> AudioStream:
	var ogg_path := base_path + ".ogg"
	if FileAccess.file_exists(ogg_path):
		return AudioStreamOggVorbis.load_from_file(ogg_path)
	var mp3_path := base_path + ".mp3"
	if FileAccess.file_exists(mp3_path):
		return AudioStreamMP3.load_from_file(mp3_path)
	var wav_path := base_path + ".wav"
	if FileAccess.file_exists(wav_path):
		return AudioStreamWAV.load_from_file(wav_path)
	return null

func _exit_tree() -> void:
	for player in _active_players:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_active_players.clear()

## ---- 合成音回退 ----

func _make_tone(frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_count := int(float(MIX_RATE) * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	for i in range(sample_count):
		var t := float(i) / float(MIX_RATE)
		var fade_in := clampf(t / 0.01, 0.0, 1.0)
		var fade_out := clampf((duration - t) / 0.04, 0.0, 1.0)
		var envelope := minf(fade_in, fade_out)
		var sample := sin(TAU * frequency * t) * volume * envelope
		var value := int(clampf(sample, -1.0, 1.0) * 32767.0)
		if value < 0:
			value += 65536

		bytes[i * 2] = value & 0xff
		bytes[i * 2 + 1] = (value >> 8) & 0xff

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
