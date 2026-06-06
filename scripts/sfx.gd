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
## 字段：wave(sine/triangle/square/saw/noise)、freq/freq_end(扫频)、sequence(多音阶琶音)、
##       duration、volume、noise(白噪混入比 0~1)、decay(指数衰减率)、pitch_var(每次播放随机变调幅度)
var _profiles: Dictionary = {
	# 豌豆开火：向下"啾"一声 + 一点噪声咔哒
	"shoot": {"wave": "triangle", "freq": 860.0, "freq_end": 520.0, "duration": 0.09, "volume": 0.30, "noise": 0.06, "decay": 11.0, "pitch_var": 0.09},
	# 命中：噪声为主的短促"啪"
	"hit": {"wave": "triangle", "freq": 300.0, "freq_end": 170.0, "duration": 0.08, "volume": 0.30, "noise": 0.45, "decay": 16.0, "pitch_var": 0.12},
	# 击退僵尸：明亮的两音上扬
	"kill": {"wave": "triangle", "sequence": [640.0, 880.0], "duration": 0.14, "volume": 0.26, "decay": 9.0, "pitch_var": 0.06},
	# 漏怪：低沉下滑
	"leak": {"wave": "sine", "freq": 330.0, "freq_end": 110.0, "duration": 0.22, "volume": 0.32, "decay": 5.0, "pitch_var": 0.0},
	# 新波来袭：上扬警示
	"wave": {"wave": "triangle", "sequence": [440.0, 660.0], "duration": 0.20, "volume": 0.24, "decay": 6.0, "pitch_var": 0.0},
	# 升级：三音上行琶音
	"upgrade": {"wave": "triangle", "sequence": [660.0, 880.0, 1120.0], "duration": 0.21, "volume": 0.24, "decay": 7.0, "pitch_var": 0.0},
	# 铲除：短促下滑
	"sell": {"wave": "triangle", "freq": 520.0, "freq_end": 300.0, "duration": 0.12, "volume": 0.22, "decay": 9.0, "pitch_var": 0.0},
	# 胜利：C-E-G-C 上行小号
	"win": {"wave": "triangle", "sequence": [523.0, 659.0, 784.0, 1047.0], "duration": 0.5, "volume": 0.26, "decay": 4.0, "pitch_var": 0.0},
	# 失败：三音下行
	"game_over": {"wave": "triangle", "sequence": [330.0, 247.0, 165.0], "duration": 0.45, "volume": 0.32, "decay": 4.0, "pitch_var": 0.0},
	# Boss 出场：低沉嗡鸣警示
	"boss": {"wave": "saw", "freq": 130.0, "freq_end": 90.0, "duration": 0.55, "volume": 0.32, "decay": 2.5, "pitch_var": 0.0},
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
	# 每次播放随机微调音高，避免重复音效（如连续开火）听起来完全一致；
	# 同样作用于真实音频文件
	var pitch_var := float((_profiles.get(sfx_name, {}) as Dictionary).get("pitch_var", 0.05))
	if pitch_var > 0.0:
		player.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
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
	return _synthesize(_profiles[sfx_name])

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

## ---- 合成音回退（小型合成器）----

## 根据 profile 合成一段音频：支持扫频单音或 sequence 琶音
func _synthesize(profile: Dictionary) -> AudioStreamWAV:
	var duration := float(profile.get("duration", 0.1))
	var sample_count := maxi(int(float(MIX_RATE) * duration), 1)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	var sequence: Array = profile.get("sequence", [])
	if sequence.is_empty():
		var freq := float(profile.get("freq", 600.0))
		_render_segment(bytes, 0, sample_count, profile, freq, float(profile.get("freq_end", freq)))
	else:
		# 把总时长均分给每个音，逐段独立拨弦式渲染
		var seg_len := int(sample_count / sequence.size())
		for n in range(sequence.size()):
			var start := n * seg_len
			var count := seg_len if n < sequence.size() - 1 else sample_count - start
			var note := float(sequence[n])
			_render_segment(bytes, start, count, profile, note, note)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream

## 把一段振荡器+包络写入 bytes[start..start+count)（16-bit PCM）
func _render_segment(bytes: PackedByteArray, start: int, count: int, profile: Dictionary, freq_start: float, freq_end: float) -> void:
	var wave := String(profile.get("wave", "sine"))
	var volume := float(profile.get("volume", 0.25))
	var noise_amount := float(profile.get("noise", 0.0))
	var attack := float(profile.get("attack", 0.006))
	var decay := float(profile.get("decay", 8.0))
	var seg_duration := maxf(float(count) / float(MIX_RATE), 0.0001)
	var phase := 0.0

	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var freq := lerpf(freq_start, freq_end, t / seg_duration)
		phase += TAU * freq / float(MIX_RATE)
		var osc := _wave_sample(wave, phase)
		if noise_amount > 0.0:
			osc = lerpf(osc, randf() * 2.0 - 1.0, noise_amount)

		# 包络：起音 + 指数衰减 + 收尾淡出（避免段间咔哒）
		var release := clampf((seg_duration - t) / 0.012, 0.0, 1.0)
		var envelope := clampf(t / attack, 0.0, 1.0) * exp(-t * decay) * release
		var value := int(clampf(osc * volume * envelope, -1.0, 1.0) * 32767.0)
		if value < 0:
			value += 65536

		var idx := (start + i) * 2
		bytes[idx] = value & 0xff
		bytes[idx + 1] = (value >> 8) & 0xff

func _wave_sample(wave: String, phase: float) -> float:
	match wave:
		"square":
			return 1.0 if sin(phase) >= 0.0 else -1.0
		"triangle":
			return asin(sin(phase)) * (2.0 / PI)
		"saw":
			return fposmod(phase / TAU, 1.0) * 2.0 - 1.0
		"noise":
			return randf() * 2.0 - 1.0
		_:
			return sin(phase)
