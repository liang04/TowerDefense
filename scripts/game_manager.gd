## 游戏全局管理器（Autoload 单例）
## 管理：金币、生命、塔放置网格、游戏状态
extends Node

## ---- 信号 ----
signal gold_changed(new_gold: int)
signal lives_changed(new_lives: int)
signal game_over
signal wave_started(wave_num: int)
signal wave_completed(wave_num: int)

## ---- 常量 ----
const CELL_SIZE := 80       # 网格单元像素大小
const GRID_COLS := 12       # 地图列数（宽）
const GRID_ROWS := 8        # 地图行数（高）

## ---- 初始值 ----
const STARTING_GOLD := 100
const STARTING_LIVES := 20
const TOWER_COST := 50

## ---- 状态 ----
var gold: int = STARTING_GOLD
var lives: int = STARTING_LIVES
var is_game_over: bool = false

## 网格占用表：key = Vector2i(列, 行), value = true 表示已占用
var occupied_cells: Dictionary = {}

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
func try_place_tower(grid_col: int, grid_row: int, cost: int) -> bool:
	var cell := Vector2i(grid_col, grid_row)

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

## 检查某格子是否可放塔
func can_place_tower(grid_col: int, grid_row: int) -> bool:
	var cell := Vector2i(grid_col, grid_row)
	return cell not in occupied_cells and cell not in path_cells \
		and grid_col >= 0 and grid_col < GRID_COLS \
		and grid_row >= 0 and grid_row < GRID_ROWS

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

## 怪物到达终点
func lose_life(amount: int = 1) -> void:
	if is_game_over:
		return
	lives -= amount
	if lives < 0:
		lives = 0
	lives_changed.emit(lives)
	if lives <= 0:
		is_game_over = true
		game_over.emit()

## 波次事件
func notify_wave_started(wave_num: int) -> void:
	wave_started.emit(wave_num)

func notify_wave_completed(wave_num: int) -> void:
	wave_completed.emit(wave_num)

func reset_game() -> void:
	gold = STARTING_GOLD
	lives = STARTING_LIVES
	is_game_over = false
	occupied_cells.clear()
	_init_path()
	gold_changed.emit(gold)
	lives_changed.emit(lives)
