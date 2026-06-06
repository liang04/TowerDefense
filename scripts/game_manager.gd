## 游戏全局管理器（Autoload 单例）
## 管理：金币、生命、塔放置网格、游戏状态
extends Node

var LevelData = preload("res://scripts/level_data.gd")

## ---- 信号 ----
signal gold_changed(new_gold: int)
signal lives_changed(new_lives: int)
signal life_lost(new_lives: int)
signal game_over
signal game_won
signal wave_started(wave_num: int)
signal wave_completed(wave_num: int)
signal wave_countdown(seconds_left: int)
signal tower_selection_changed(tower_type: String)
signal sfx_requested(sfx_name: String)
signal level_changed(level_index: int, level_name: String)
signal game_speed_changed(speed: float)
signal enemy_killed(world_pos: Vector2, reward: int, color: Color)

## ---- 常量 ----
const CELL_SIZE := 80       # 网格单元像素大小
const GRID_COLS := 12       # 地图列数（宽）
const GRID_ROWS := 8        # 地图行数（高）
const MAP_OFFSET_Y := 48    # 地图整体下移的像素，给顶部信息栏留出空间

## 塔的等级缩放参数（塔实体与 HUD 显示共用，避免公式重复）
const LEVEL_DAMAGE_SCALE_PER_LEVEL := 0.45   # 每级伤害加成比例
const LEVEL_RANGE_BONUS_PER_LEVEL := 14.0    # 每级射程加成（像素）
const LEVEL_COOLDOWN_SCALE_PER_LEVEL := 0.12 # 每级冷却缩减比例
const MIN_COOLDOWN := 0.18                    # 冷却时间下限（秒）

## 可选的游戏速度倍率（快进），按顺序循环切换
const GAME_SPEEDS: Array[float] = [1.0, 2.0, 3.0]

## 进度存档路径（用户数据目录，跨会话持久化）
const SAVE_PATH := "user://savegame.cfg"

const ENEMY_TYPE_NAMES := {
	"grunt": "普通怪",
	"runner": "快速怪",
	"tank": "重甲怪",
}

const ENEMY_TYPE_ADVICE := {
	"grunt": "箭塔",
	"runner": "冰塔",
	"tank": "炮塔",
}

var tower_configs: Dictionary = {
	"arrow": {
		"name": "箭塔",
		"cost": 45,
		"damage": 9,
		"range": 170.0,
		"cooldown": 0.65,
		"slow_multiplier": 1.0,
		"slow_duration": 0.0,
		"splash_radius": 0.0,
		"color": Color(0.2, 0.45, 0.95),
		"description": "均衡、便宜、射速快",
	},
	"cannon": {
		"name": "炮塔",
		"cost": 75,
		"damage": 24,
		"range": 145.0,
		"cooldown": 1.25,
		"slow_multiplier": 1.0,
		"slow_duration": 0.0,
		"splash_radius": 58.0,
		"color": Color(0.9, 0.35, 0.18),
		"description": "伤害高、射速慢、范围溅射",
	},
	"frost": {
		"name": "冰塔",
		"cost": 60,
		"damage": 5,
		"range": 155.0,
		"cooldown": 0.9,
		"slow_multiplier": 0.55,
		"slow_duration": 1.4,
		"splash_radius": 0.0,
		"color": Color(0.25, 0.75, 0.95),
		"description": "伤害低，可减速",
	},
}

## ---- 状态 ----
var levels: Array[Dictionary] = []
var current_level_index: int = 0
var max_unlocked_level: int = 0
var gold: int = 160
var lives: int = 20
var is_game_over: bool = false
var selected_tower_type: String = "arrow"
var current_wave: int = 0
var enemies_killed: int = 0
var enemies_leaked: int = 0
var game_speed_index: int = 0

## 网格占用表：key = Vector2i(列, 行), value = true 表示已占用
var occupied_cells: Dictionary = {}
var towers_by_cell: Dictionary = {}

## 路径格子集合（不可放塔）
var path_cells: Dictionary = {}

## 怪物行进路径点（像素坐标序列）
var path_points: PackedVector2Array = []

## ---- 初始化 ----
func _ready() -> void:
	levels = LevelData.get_levels()
	if levels.is_empty():
		push_error("No level data configured.")
		return
	_load_progress()
	_apply_level_settings()
	_init_path()

## ---- 进度存档 ----

## 关卡是否已解锁（第 0 关始终解锁，其余需通关前一关）
func is_level_unlocked(level_index: int) -> bool:
	return level_index >= 0 and level_index <= max_unlocked_level

## 读取存档，恢复已解锁关卡与上次游玩关卡；无存档或损坏时回退默认进度
func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	var last_index := int(levels.size() - 1)
	var saved_max := int(config.get_value("progress", "max_unlocked_level", 0))
	var saved_last := int(config.get_value("progress", "last_level_index", 0))
	max_unlocked_level = clampi(saved_max, 0, last_index)
	current_level_index = clampi(saved_last, 0, max_unlocked_level)

func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "max_unlocked_level", max_unlocked_level)
	config.set_value("progress", "last_level_index", current_level_index)
	config.save(SAVE_PATH)

## 初始化路径（坐标为网格 列,行）
func _init_path() -> void:
	path_cells.clear()
	path_points.clear()

	var path_grid: Array = get_current_level().get("path", [])

	# 注册路径格子为不可放置
	for cell in path_grid:
		path_cells[cell] = true

	# 转换为像素坐标（格子中心）
	for cell in path_grid:
		path_points.append(Vector2(
			cell.x * CELL_SIZE + CELL_SIZE * 0.5,
			cell.y * CELL_SIZE + CELL_SIZE * 0.5 + MAP_OFFSET_Y
		))

func _apply_level_settings() -> void:
	var level := get_current_level()
	gold = int(level.get("starting_gold", 160))
	lives = int(level.get("starting_lives", 20))

## ---- 公共方法 ----

## 尝试在指定网格位置放塔，成功返回 true
func try_place_tower(grid_col: int, grid_row: int, tower_type: String) -> bool:
	var cell := Vector2i(grid_col, grid_row)
	var cost := get_tower_cost(tower_type)

	if is_game_over:
		return false
	if grid_col < 0 or grid_col >= GRID_COLS or grid_row < 0 or grid_row >= GRID_ROWS:
		return false
	if cell in occupied_cells or cell in path_cells:
		return false
	if gold < cost:
		return false

	gold -= cost
	occupied_cells[cell] = true
	gold_changed.emit(gold)
	return true

func register_tower(grid_col: int, grid_row: int, tower: Node) -> void:
	var cell := Vector2i(grid_col, grid_row)
	towers_by_cell[cell] = tower

func remove_tower(grid_col: int, grid_row: int) -> void:
	var cell := Vector2i(grid_col, grid_row)
	occupied_cells.erase(cell)
	towers_by_cell.erase(cell)

func get_tower_at(grid_col: int, grid_row: int) -> Node:
	var cell := Vector2i(grid_col, grid_row)
	var tower = towers_by_cell.get(cell, null)
	if tower is Node:
		return tower
	return null

## 检查某格子是否可放塔
func can_place_tower(grid_col: int, grid_row: int) -> bool:
	var cell := Vector2i(grid_col, grid_row)
	return cell not in occupied_cells and cell not in path_cells \
		and grid_col >= 0 and grid_col < GRID_COLS \
		and grid_row >= 0 and grid_row < GRID_ROWS

func can_afford(amount: int) -> bool:
	return gold >= amount

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func get_tower_config(tower_type: String) -> Dictionary:
	if tower_type in tower_configs:
		return tower_configs[tower_type]
	return tower_configs["arrow"]

func get_tower_cost(tower_type: String) -> int:
	return int(get_tower_config(tower_type)["cost"])

## 按等级缩放后的塔数值（伤害/射程/冷却/减速），塔实体与 HUD 共用此唯一公式
func get_scaled_tower_stats(tower_type: String, tower_level: int = 1) -> Dictionary:
	var config := get_tower_config(tower_type)
	var level_offset := float(tower_level - 1)
	var damage_scale := 1.0 + level_offset * LEVEL_DAMAGE_SCALE_PER_LEVEL
	var cooldown_scale := 1.0 - level_offset * LEVEL_COOLDOWN_SCALE_PER_LEVEL
	return {
		"damage": int(round(float(config["damage"]) * damage_scale)),
		"range": float(config["range"]) + level_offset * LEVEL_RANGE_BONUS_PER_LEVEL,
		"cooldown": maxf(float(config["cooldown"]) * cooldown_scale, MIN_COOLDOWN),
		"slow_multiplier": float(config["slow_multiplier"]),
		"slow_duration": float(config["slow_duration"]),
		"splash_radius": float(config.get("splash_radius", 0.0)),
	}

func get_tower_stats_text(tower_type: String, tower_level: int = 1) -> String:
	var stats := get_scaled_tower_stats(tower_type, tower_level)
	var slow_multiplier := float(stats["slow_multiplier"])
	var slow_duration := float(stats["slow_duration"])
	var splash_radius := float(stats["splash_radius"])
	var parts: Array[String] = [
		"伤害 %d" % int(stats["damage"]),
		"射程 %d" % int(round(float(stats["range"]))),
		"间隔 %.2fs" % float(stats["cooldown"]),
	]

	if splash_radius > 0.0:
		parts.append("溅射 R%d" % int(round(splash_radius)))

	if slow_duration > 0.0 and slow_multiplier < 1.0:
		parts.append("减速 %d%% %.1fs" % [int(round((1.0 - slow_multiplier) * 100.0)), slow_duration])

	return " | ".join(parts)

func set_selected_tower_type(tower_type: String) -> void:
	if not (tower_type in tower_configs):
		return
	selected_tower_type = tower_type
	tower_selection_changed.emit(selected_tower_type)

## 网格坐标转像素坐标（格子中心）
func grid_to_pixel(grid_col: int, grid_row: int) -> Vector2:
	return Vector2(grid_col * CELL_SIZE + CELL_SIZE * 0.5,
				   grid_row * CELL_SIZE + CELL_SIZE * 0.5 + MAP_OFFSET_Y)

## 像素坐标转网格坐标
func pixel_to_grid(pixel_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pixel_pos.x / CELL_SIZE)),
				   int(floor((pixel_pos.y - MAP_OFFSET_Y) / CELL_SIZE)))

## 击杀奖励
func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func notify_enemy_killed(world_pos: Vector2, reward: int, color: Color) -> void:
	enemies_killed += 1
	request_sfx("kill")
	enemy_killed.emit(world_pos, reward, color)

## 怪物到达终点
func lose_life(amount: int = 1) -> void:
	if is_game_over:
		return
	enemies_leaked += amount
	lives -= amount
	if lives < 0:
		lives = 0
	lives_changed.emit(lives)
	life_lost.emit(lives)
	request_sfx("leak")
	if lives <= 0:
		is_game_over = true
		request_sfx("game_over")
		game_over.emit()

## 波次事件
func notify_wave_started(wave_num: int) -> void:
	current_wave = wave_num
	request_sfx("wave")
	wave_started.emit(wave_num)

func notify_wave_completed(wave_num: int) -> void:
	wave_completed.emit(wave_num)

func notify_wave_countdown(seconds_left: int) -> void:
	wave_countdown.emit(seconds_left)

func win_game() -> void:
	if is_game_over:
		return
	is_game_over = true
	_unlock_next_level()
	request_sfx("win")
	game_won.emit()

## 通关后解锁下一关并写入存档（已是最后一关时仅保存进度）
func _unlock_next_level() -> void:
	var next_index := mini(current_level_index + 1, levels.size() - 1)
	if next_index > max_unlocked_level:
		max_unlocked_level = next_index
	_save_progress()

func request_sfx(sfx_name: String) -> void:
	sfx_requested.emit(sfx_name)

## 当前游戏速度倍率
func get_game_speed() -> float:
	return GAME_SPEEDS[game_speed_index]

## 循环切换游戏速度（1x → 2x → 3x → 1x），通过 Engine.time_scale 统一加速
## 移动、冷却、刷怪定时器、波次倒计时与间隔
func cycle_game_speed() -> void:
	game_speed_index = (game_speed_index + 1) % GAME_SPEEDS.size()
	_apply_time_scale()
	game_speed_changed.emit(get_game_speed())

func _apply_time_scale() -> void:
	Engine.time_scale = get_game_speed()

func reset_game() -> void:
	_apply_level_settings()
	is_game_over = false
	current_wave = 0
	enemies_killed = 0
	enemies_leaked = 0
	occupied_cells.clear()
	towers_by_cell.clear()
	selected_tower_type = "arrow"
	_init_path()
	gold_changed.emit(gold)
	lives_changed.emit(lives)
	tower_selection_changed.emit(selected_tower_type)
	level_changed.emit(current_level_index, get_current_level_name())

func advance_to_next_level() -> bool:
	if current_level_index + 1 >= levels.size():
		return false
	current_level_index += 1
	_save_progress()
	reset_game()
	return true

func set_level(level_index: int) -> bool:
	if level_index < 0 or level_index >= levels.size():
		return false
	if not is_level_unlocked(level_index):
		return false
	current_level_index = level_index
	_save_progress()
	reset_game()
	return true

func get_current_level() -> Dictionary:
	if levels.is_empty():
		return {}
	return levels[current_level_index]

func get_current_level_name() -> String:
	return String(get_current_level().get("name", "未命名关卡"))

func get_current_level_description() -> String:
	return String(get_current_level().get("description", ""))

func get_current_level_waves() -> Array:
	return get_current_level().get("waves", [])

func get_wave_count() -> int:
	return get_current_level_waves().size()

func get_wave_preview_text(wave_num: int, prefix: String = "下一波") -> String:
	var waves := get_current_level_waves()
	if wave_num < 1 or wave_num > waves.size():
		return "所有波次已完成"

	var wave: Dictionary = waves[wave_num - 1]
	var groups: Array = wave.get("groups", [])
	var counts: Dictionary = {}
	var order: Array[String] = []

	for group in groups:
		var enemy_type := String(group.get("type", "grunt"))
		if not (enemy_type in counts):
			counts[enemy_type] = 0
			order.append(enemy_type)
		counts[enemy_type] += int(group.get("count", 0))

	var parts: Array[String] = []
	var advice: Array[String] = []
	for enemy_type in order:
		var enemy_name := String(ENEMY_TYPE_NAMES.get(enemy_type, enemy_type))
		parts.append("%s x%d" % [enemy_name, int(counts[enemy_type])])
		var advice_text := String(ENEMY_TYPE_ADVICE.get(enemy_type, "箭塔"))
		if not (advice_text in advice):
			advice.append(advice_text)

	return "%s %d/%d：%s | 建议：%s" % [
		prefix,
		wave_num,
		waves.size(),
		"、".join(parts),
		"、".join(advice),
	]

func has_next_level() -> bool:
	return current_level_index + 1 < levels.size()

func get_level_count() -> int:
	return levels.size()

func get_level_background_color() -> Color:
	var value = get_current_level().get("background", Color(0.11, 0.2, 0.13))
	return value if value is Color else Color(0.11, 0.2, 0.13)

func get_level_buildable_color() -> Color:
	var value = get_current_level().get("buildable_color", Color(0.18, 0.55, 0.24, 0.22))
	return value if value is Color else Color(0.18, 0.55, 0.24, 0.22)

func get_level_path_color() -> Color:
	var value = get_current_level().get("path_color", Color(0.35, 0.28, 0.2))
	return value if value is Color else Color(0.35, 0.28, 0.2)

## 关卡整体光照色调（默认中性白，即不改变观感）
func get_level_ambient_color() -> Color:
	var value = get_current_level().get("ambient_color", Color(1, 1, 1))
	return value if value is Color else Color(1, 1, 1)
