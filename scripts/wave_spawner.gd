## 波次生成器
## 按波次配置生成敌人，管理波次节奏
class_name WaveSpawner
extends Node

## ---- 信号 ----
signal all_waves_completed

const COUNTDOWN_SECONDS := 2

## ---- 预加载 ----
var _enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")

## ---- 状态 ----
var _current_wave: int = 0
var _enemies_alive: int = 0
var _is_spawning: bool = false
var _is_finished: bool = false
var _current_group: int = 0
var _is_waiting_to_spawn: bool = false

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
	if _is_spawning or _is_waiting_to_spawn or GameManager.is_game_over or _is_finished:
		return

	var waves := GameManager.get_current_level_waves()
	if _current_wave >= waves.size():
		_is_finished = true
		all_waves_completed.emit()
		return

	_is_waiting_to_spawn = true
	await _run_countdown()
	_is_waiting_to_spawn = false
	if GameManager.is_game_over or _is_finished or not is_inside_tree():
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
	var enemy := _enemy_scene.instantiate() as Enemy

	enemy.setup(wave_data)

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

		var waves := GameManager.get_current_level_waves()
		var groups: Array = waves[_current_wave]["groups"]
		if _current_group >= groups.size():
			spawn_timer.stop()
			_is_spawning = false
		else:
			var next_data := _get_current_spawn_data()
			spawn_timer.wait_time = next_data["interval"]

func _get_current_spawn_data() -> Dictionary:
	var waves := GameManager.get_current_level_waves()
	var groups: Array = waves[_current_wave]["groups"]
	return groups[_current_group]

func _run_countdown() -> void:
	for seconds_left in range(COUNTDOWN_SECONDS, 0, -1):
		GameManager.notify_wave_countdown(seconds_left)
		if not is_inside_tree():
			return
		var tree := get_tree()
		await tree.create_timer(1.0).timeout
		if GameManager.is_game_over:
			return

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
		await tree.create_timer(1.2).timeout
		if not is_inside_tree():
			return
		start_next_wave()
