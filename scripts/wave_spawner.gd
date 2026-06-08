## 波次生成器
## 按波次配置生成敌人，管理波次节奏
class_name WaveSpawner
extends Node

## ---- 信号 ----
signal all_waves_completed

const COUNTDOWN_SECONDS := 2

## ---- 预加载 ----
var _enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")

## ---- 状态机 ----
## 这些状态互斥，用单一 _state 表示，避免多个布尔标志出现非法组合
## （如同时"正在生成"又"等待生成"）。
enum State {
	IDLE,           # 未开始下一波，等待玩家（初始/关卡刚载入）
	COUNTDOWN,      # 波次开始前的倒计时
	SPAWNING,       # 正在生成本波敌人
	CLEARING,       # 已生成完，等待场上敌人被清空
	BETWEEN_WAVES,  # 本波清空、下一波未开始的可催窗口
	FINISHED,       # 所有波次完成
}
var _state: State = State.IDLE

## 与状态正交的中断标志：玩家催波时置位，被倒计时与波间等待轮询以"快进"。
## 独立于 _state，因为它可在 BETWEEN_WAVES / COUNTDOWN 两个等待阶段连续生效。
var _skip_requested: bool = false

## ---- 计数器（非状态，描述当前进度）----
var _current_wave: int = 0
var _enemies_alive: int = 0
var _current_group: int = 0
var _spawned_count: int = 0

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
	# 仅在"未生成 / 清场中 / 波间"且游戏进行中时可开始；生成中、倒计时中、已结束则忽略
	if _state == State.SPAWNING or _state == State.COUNTDOWN \
			or _state == State.FINISHED or GameManager.is_game_over:
		return

	var waves := GameManager.get_current_level_waves()
	if _current_wave >= waves.size():
		_state = State.FINISHED
		all_waves_completed.emit()
		return

	_state = State.COUNTDOWN
	await _run_countdown()
	if GameManager.is_game_over or _state != State.COUNTDOWN or not is_inside_tree():
		return

	# 倒计时后才复位 skip：催波置的 skip 需先把倒计时一并快进掉
	_skip_requested = false
	_state = State.SPAWNING
	_enemies_alive = 0
	_spawned_count = 0
	_current_group = 0
	GameManager.notify_wave_started(_current_wave + 1)

	var spawn_data := _get_current_spawn_data()
	spawn_timer.wait_time = spawn_data["interval"]
	spawn_timer.start()
	_on_spawn_timer_timeout()

## 玩家请求提前开始下一波；仅在波间窗口有效，返回是否成功
func request_next_wave_now() -> bool:
	# skip 已置位表示窗口已被本次催波关闭，避免重复触发（奖励/跳过只生效一次）
	if _state != State.BETWEEN_WAVES or _skip_requested or GameManager.is_game_over:
		return false
	if _current_wave >= GameManager.get_current_level_waves().size():
		return false  # 最后一波清完的窗口，已无下一波可催
	# 置 skip：打断波间等待并快进随后的倒计时，立即开战
	_skip_requested = true
	return true

## ---- 内部方法 ----

func _spawn_enemy() -> void:
	if GameManager.is_game_over:
		return

	var wave_data := _get_current_spawn_data()
	var enemy := _enemy_scene.instantiate() as Enemy

	enemy.setup(GameManager.get_scaled_enemy_data(wave_data))

	enemies_container.add_child(enemy)
	_enemies_alive += 1

	# 监听敌人销毁
	enemy.tree_exited.connect(_on_enemy_died)

func _get_current_spawn_data() -> Dictionary:
	var waves := GameManager.get_current_level_waves()
	var groups: Array = waves[_current_wave]["groups"]
	return groups[_current_group]

func _run_countdown() -> void:
	for seconds_left in range(COUNTDOWN_SECONDS, 0, -1):
		if _skip_requested or not is_inside_tree():
			return
		GameManager.notify_wave_countdown(seconds_left)
		await _interruptible_wait(1.0)
		if GameManager.is_game_over:
			return

## 可被"提前催下一波"打断的等待（按 0.05s 粒度轮询 skip 标志，
## 同样响应游戏结束与节点移除）；总时长随 Engine.time_scale 缩放，与快进一致
func _interruptible_wait(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		if _skip_requested or GameManager.is_game_over or not is_inside_tree():
			return
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05

## ---- 信号回调 ----

func _on_spawn_timer_timeout() -> void:
	if GameManager.is_game_over:
		spawn_timer.stop()
		_state = State.CLEARING
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
			# 本波全部敌人已生成，转入清场等待
			spawn_timer.stop()
			_state = State.CLEARING
		else:
			var next_data := _get_current_spawn_data()
			spawn_timer.wait_time = next_data["interval"]

func _on_enemy_died() -> void:
	_enemies_alive -= 1
	if GameManager.is_game_over:
		return
	# 仅当本波已生成完（清场中）且场上清空时，才算波次完成
	if _enemies_alive <= 0 and _state == State.CLEARING:
		GameManager.notify_wave_completed(_current_wave + 1)
		_current_wave += 1
		if not is_inside_tree():
			return
		# 进入波间窗口，短暂延迟后开始下一波（给玩家准备时间，可被催波打断）
		_state = State.BETWEEN_WAVES
		_skip_requested = false
		await _interruptible_wait(1.2)
		if not is_inside_tree():
			return
		start_next_wave()
