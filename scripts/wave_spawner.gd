## 波次生成器
## 按波次配置生成敌人，管理波次节奏
extends Node

## ---- 信号 ----
signal all_waves_completed

## ---- 波次配置 ----
## 后续规模变大时可改为 Resource 或 JSON 加载
## 每波：[敌人数量, 生成间隔, 敌人血量, 敌人速度]
var waves: Array[Dictionary] = [
	{"count": 5,  "interval": 1.0, "hp": 30,  "speed": 120.0, "reward": 10},  # 第1波：简单
	{"count": 8,  "interval": 0.8, "hp": 45,  "speed": 120.0, "reward": 10},  # 第2波：多了
	{"count": 6,  "interval": 1.0, "hp": 60,  "speed": 150.0, "reward": 12},  # 第3波：更快更强
	{"count": 10, "interval": 0.6, "hp": 50,  "speed": 130.0, "reward": 10},  # 第4波：数量压力
	{"count": 5,  "interval": 1.2, "hp": 120, "speed": 100.0, "reward": 20},  # 第5波：精英怪
]

## ---- 预加载 ----
var _enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")

## ---- 状态 ----
var _current_wave: int = 0
var _enemies_alive: int = 0
var _is_spawning: bool = false
var _is_finished: bool = false

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
	GameManager.notify_wave_started(_current_wave + 1)

	var wave_data := waves[_current_wave]
	spawn_timer.wait_time = wave_data["interval"]
	spawn_timer.start()
	_on_spawn_timer_timeout()

## ---- 内部方法 ----

func _spawn_enemy() -> void:
	if GameManager.is_game_over:
		return

	var wave_data := waves[_current_wave]
	var enemy := _enemy_scene.instantiate()

	enemy.max_hp = wave_data["hp"]
	enemy.hp = wave_data["hp"]
	enemy.speed = wave_data["speed"]
	enemy.reward = wave_data["reward"]

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

	var wave_data := waves[_current_wave]
	_spawn_enemy()
	_spawned_count += 1

	if _spawned_count >= wave_data["count"]:
		spawn_timer.stop()
		_spawned_count = 0
		_is_spawning = false

func _on_enemy_died() -> void:
	_enemies_alive -= 1
	if GameManager.is_game_over:
		return
	if _enemies_alive <= 0 and not _is_spawning:
		# 当前波次所有敌人已消灭
		GameManager.notify_wave_completed(_current_wave + 1)
		_current_wave += 1
		# 短暂延迟后开始下一波（给玩家准备时间）
		await get_tree().create_timer(2.0).timeout
		start_next_wave()
