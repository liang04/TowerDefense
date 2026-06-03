extends Node

const MIX_RATE := 22050

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

func _ready() -> void:
	GameManager.sfx_requested.connect(_on_sfx_requested)

func _on_sfx_requested(sfx_name: String) -> void:
	if not (sfx_name in _profiles):
		return

	var profile: Dictionary = _profiles[sfx_name]
	var stream := _make_tone(
		float(profile["frequency"]),
		float(profile["duration"]),
		float(profile["volume"])
	)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -8.0
	add_child(player)
	_active_players.append(player)
	player.finished.connect(func() -> void:
		_active_players.erase(player)
		player.queue_free()
	)
	player.play()

func _exit_tree() -> void:
	for player in _active_players:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_active_players.clear()

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
