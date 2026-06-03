## 游戏全局管理器（Autoload 单例）
## 管理：金币、生命、塔放置网格、游戏状态
extends Node

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

## ---- 常量 ----
const CELL_SIZE := 80       # 网格单元像素大小
const GRID_COLS := 12       # 地图列数（宽）
const GRID_ROWS := 8        # 地图行数（高）

## ---- 初始值 ----
const STARTING_GOLD := 160
const STARTING_LIVES := 20

var tower_configs: Dictionary = {
	"arrow": {
		"name": "箭塔",
		"cost": 45,
		"damage": 9,
		"range": 170.0,
		"cooldown": 0.65,
		"slow_multiplier": 1.0,
		"slow_duration": 0.0,
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
		"color": Color(0.9, 0.35, 0.18),
		"description": "伤害高，射速慢",
	},
	"frost": {
		"name": "冰塔",
		"cost": 60,
		"damage": 5,
		"range": 155.0,
		"cooldown": 0.9,
		"slow_multiplier": 0.55,
		"slow_duration": 1.4,
		"color": Color(0.25, 0.75, 0.95),
		"description": "伤害低，可减速",
	},
}

## ---- 状态 ----
var gold: int = STARTING_GOLD
var lives: int = STARTING_LIVES
var is_game_over: bool = false
var selected_tower_type: String = "arrow"
var current_wave: int = 0
var enemies_killed: int = 0
var enemies_leaked: int = 0

## 网格占用表：key = Vector2i(列, 行), value = true 表示已占用
var occupied_cells: Dictionary = {}
var towers_by_cell: Dictionary = {}

## 路径格子集合（不可放塔）
var path_cells: Dictionary = {}

## 怪物行进路径点（像素坐标序列）
var path_points: PackedVector2Array = []

## ---- 初始化 ----
func _ready() -> void:
	_init_path()

## 初始化路径（坐标为网格 列,行）
func _init_path() -> void:
	path_cells.clear()
	path_points.clear()

	# 路径网格坐标序列：从左上蜿蜒到右下
	var path_grid: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(3, 2), Vector2i(3, 3),
		Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3),
		Vector2i(7, 2), Vector2i(7, 1),
		Vector2i(8, 1), Vector2i(9, 1),
		Vector2i(9, 2), Vector2i(9, 3), Vector2i(9, 4), Vector2i(9, 5),
		Vector2i(8, 5), Vector2i(7, 5), Vector2i(6, 5),
		Vector2i(6, 6), Vector2i(6, 7),
		Vector2i(7, 7), Vector2i(8, 7), Vector2i(9, 7), Vector2i(10, 7), Vector2i(11, 7),
	]

	# 注册路径格子为不可放置
	for cell in path_grid:
		path_cells[cell] = true

	# 转换为像素坐标（格子中心）
	for cell in path_grid:
		path_points.append(Vector2(
			cell.x * CELL_SIZE + CELL_SIZE * 0.5,
			cell.y * CELL_SIZE + CELL_SIZE * 0.5
		))

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

func set_selected_tower_type(tower_type: String) -> void:
	if not (tower_type in tower_configs):
		return
	selected_tower_type = tower_type
	tower_selection_changed.emit(selected_tower_type)

## 网格坐标转像素坐标（格子中心）
func grid_to_pixel(grid_col: int, grid_row: int) -> Vector2:
	return Vector2(grid_col * CELL_SIZE + CELL_SIZE * 0.5,
				   grid_row * CELL_SIZE + CELL_SIZE * 0.5)

## 像素坐标转网格坐标
func pixel_to_grid(pixel_pos: Vector2) -> Vector2i:
	return Vector2i(int(pixel_pos.x / CELL_SIZE), int(pixel_pos.y / CELL_SIZE))

## 击杀奖励
func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func notify_enemy_killed() -> void:
	enemies_killed += 1

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
	if lives <= 0:
		is_game_over = true
		game_over.emit()

## 波次事件
func notify_wave_started(wave_num: int) -> void:
	current_wave = wave_num
	wave_started.emit(wave_num)

func notify_wave_completed(wave_num: int) -> void:
	wave_completed.emit(wave_num)

func notify_wave_countdown(seconds_left: int) -> void:
	wave_countdown.emit(seconds_left)

func win_game() -> void:
	if is_game_over:
		return
	is_game_over = true
	game_won.emit()

func reset_game() -> void:
	gold = STARTING_GOLD
	lives = STARTING_LIVES
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
