## 波次生成器
## 按波次配置生成敌人，管理波次节奏
extends Node

## ---- 信号 ----
signal all_waves_completed

## ---- 波次配置 ----
## 后续规模变大时可改为 Resource 或 JSON 加载
## groups 中每组：[数量, 生成间隔, 类型, 血量, 速度, 奖励]
var waves: Array[Dictionary] = [
	{"groups": [
		{"count": 5, "interval": 0.9, "type": "grunt", "hp": 30, "speed": 118.0, "reward": 10, "color": Color(0.25, 0.8, 0.25)},
	]},
	{"groups": [
		{"count": 6, "interval": 0.75, "type": "grunt", "hp": 42, "speed": 122.0, "reward": 10, "color": Color(0.25, 0.8, 0.25)},
		{"count": 3, "interval": 0.55, "type": "runner", "hp": 24, "speed": 175.0, "reward": 12, "color": Color(0.95, 0.9, 0.25)},
	]},
	{"groups": [
		{"count": 8, "interval": 0.7, "type": "runner", "hp": 32, "speed": 185.0, "reward": 13, "color": Color(0.95, 0.9, 0.25)},
		{"count": 3, "interval": 1.0, "type": "tank", "hp": 120, "speed": 80.0, "reward": 22, "color": Color(0.62, 0.55, 0.48)},
	]},
	{"groups": [
		{"count": 12, "interval": 0.45, "type": "grunt", "hp": 58, "speed": 130.0, "reward": 11, "color": Color(0.25, 0.8, 0.25)},
		{"count": 4, "interval": 0.8, "type": "tank", "hp": 150, "speed": 85.0, "reward": 24, "color": Color(0.62, 0.55, 0.48)},
	]},
	{"groups": [
		{"count": 8, "interval": 0.5, "type": "runner", "hp": 44, "speed": 195.0, "reward": 14, "color": Color(0.95, 0.9, 0.25)},
		{"count": 6, "interval": 0.8, "type": "tank", "hp": 190, "speed": 90.0, "reward": 28, "color": Color(0.62, 0.55, 0.48)},
		{"count": 8, "interval": 0.45, "type": "grunt", "hp": 75, "speed": 140.0, "reward": 13, "color": Color(0.25, 0.8, 0.25)},
	]},
]

## ---- 预加载 ----
var _enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")

## ---- 状态 ----
var _current_wave: int = 0
var _enemies_alive: int = 0
var _is_spawning: bool = false
var _is_finished: bool = false
var _current_group: int = 0

## ---- 节点引用 ----
@onready var enemies_container: Node2D = get_node("../Enemies")
@onready var spawn_timer: Timer = $SpawnTimer

## ---- 生命周期 ----
func _ready() -> void:
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

## ---- 公共方法 ----

## 开始下一波
func start_next_wave() -> void:
	if _is_spawning or GameManager.is_game_over or _is_finished:
		return

	if _current_wave >= waves.size():
		_is_finished = true
		all_waves_completed.emit()
		return

	_is_spawning = true
	_enemies_alive = 0
	_spawned_count = 0
	_current_group = 0
	GameManager.notify_wave_started(_current_wave + 1)

	var spawn_data := _get_current_spawn_data()
	spawn_timer.wait_time = spawn_data["interval"]
	spawn_timer.start()
	_on_spawn_timer_timeout()

## ---- 内部方法 ----

func _spawn_enemy() -> void:
	if GameManager.is_game_over:
		return

	var wave_data := _get_current_spawn_data()
	var enemy := _enemy_scene.instantiate()

	if enemy.has_method("setup"):
		enemy.call("setup", wave_data)

	enemies_container.add_child(enemy)
	_enemies_alive += 1

	# 监听敌人销毁
	enemy.tree_exited.connect(_on_enemy_died)

## ---- 信号回调 ----

var _spawned_count: int = 0

func _on_spawn_timer_timeout() -> void:
	if GameManager.is_game_over:
		spawn_timer.stop()
		_is_spawning = false
		return

	var wave_data := _get_current_spawn_data()
	_spawn_enemy()
	_spawned_count += 1

	if _spawned_count >= wave_data["count"]:
		_spawned_count = 0
		_current_group += 1

		var groups: Array = waves[_current_wave]["groups"]
		if _current_group >= groups.size():
			spawn_timer.stop()
			_is_spawning = false
		else:
			var next_data := _get_current_spawn_data()
			spawn_timer.wait_time = next_data["interval"]

func _get_current_spawn_data() -> Dictionary:
	var groups: Array = waves[_current_wave]["groups"]
	return groups[_current_group]

func _on_enemy_died() -> void:
	_enemies_alive -= 1
	if GameManager.is_game_over:
		return
	if _enemies_alive <= 0 and not _is_spawning:
		# 当前波次所有敌人已消灭
		GameManager.notify_wave_completed(_current_wave + 1)
		_current_wave += 1
		# 短暂延迟后开始下一波（给玩家准备时间）
		if not is_inside_tree():
			return
		var tree := get_tree()
		await tree.create_timer(2.0).timeout
		if not is_inside_tree():
			return
		start_next_wave()
