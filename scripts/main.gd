## 主场景脚本
## 处理地图绘制、塔放置输入、游戏流程
extends Node2D

## ---- 预加载 ----
var _tower_scene: PackedScene = preload("res://scenes/tower.tscn")

## ---- 节点引用 ----
@onready var towers_container: Node2D = $Towers
@onready var wave_spawner: Node = $WaveSpawner
@onready var hud: Node = $HUD

## ---- 状态 ----
var _hover_cell: Vector2i = Vector2i(-1, -1)  # 鼠标悬停的格子
var _game_started: bool = false
var _selected_tower: Node = null
var _selected_cell: Vector2i = Vector2i(-1, -1)

## ---- 生命周期 ----
func _ready() -> void:
	# 连接信号
	GameManager.game_over.connect(_on_game_over)
	wave_spawner.connect("all_waves_completed", _on_all_waves_completed)
	queue_redraw()

func _process(_delta: float) -> void:
	# 更新悬停格子
	var mouse_pos := get_global_mouse_position()
	var new_hover := GameManager.pixel_to_grid(mouse_pos)
	if new_hover != _hover_cell:
		_hover_cell = new_hover
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_place_tower()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_start_game()

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_start_game()
		elif event.keycode == KEY_1:
			_select_tower_type("arrow")
		elif event.keycode == KEY_2:
			_select_tower_type("cannon")
		elif event.keycode == KEY_3:
			_select_tower_type("frost")
		elif event.keycode == KEY_U:
			_upgrade_selected_tower()
		elif event.keycode == KEY_X:
			_sell_selected_tower()
		elif event.keycode == KEY_R and GameManager.is_game_over:
			_restart_game()

## ---- 塔放置 ----

func _try_place_tower() -> void:
	var col := _hover_cell.x
	var row := _hover_cell.y

	var existing_tower := GameManager.get_tower_at(col, row)
	if existing_tower:
		_select_existing_tower(existing_tower, Vector2i(col, row))
		return

	if GameManager.try_place_tower(col, row, GameManager.selected_tower_type):
		var tower: Node2D = _tower_scene.instantiate()
		tower.call("setup", GameManager.selected_tower_type, Vector2i(col, row))
		tower.global_position = GameManager.grid_to_pixel(col, row)
		towers_container.add_child(tower)
		GameManager.register_tower(col, row, tower)
		_select_existing_tower(tower, Vector2i(col, row))
		queue_redraw()

func _select_tower_type(tower_type: String) -> void:
	GameManager.set_selected_tower_type(tower_type)
	_selected_tower = null
	_selected_cell = Vector2i(-1, -1)
	hud.call("show_tower_details", null)
	queue_redraw()

func _select_existing_tower(tower: Node, cell: Vector2i) -> void:
	_selected_tower = tower
	_selected_cell = cell
	hud.call("show_tower_details", tower)
	queue_redraw()

func _upgrade_selected_tower() -> void:
	if not _selected_tower or not is_instance_valid(_selected_tower):
		hud.call("show_message", "先点击选择一座塔")
		return
	if not _selected_tower.call("can_upgrade"):
		hud.call("show_message", "这座塔已经满级")
		return

	var cost := int(_selected_tower.call("get_upgrade_cost"))
	if not GameManager.spend_gold(cost):
		hud.call("show_message", "金币不足，升级需要 %d" % cost)
		return

	_selected_tower.call("upgrade")
	hud.call("show_tower_details", _selected_tower)
	queue_redraw()

func _sell_selected_tower() -> void:
	if not _selected_tower or not is_instance_valid(_selected_tower):
		hud.call("show_message", "先点击选择一座塔")
		return

	var refund := int(_selected_tower.call("get_sell_value"))
	GameManager.add_gold(refund)
	GameManager.remove_tower(_selected_cell.x, _selected_cell.y)
	_selected_tower.queue_free()
	_selected_tower = null
	_selected_cell = Vector2i(-1, -1)
	hud.call("show_tower_details", null)
	hud.call("show_message", "出售成功，返还 %d 金币" % refund)
	queue_redraw()

func _start_game() -> void:
	if _game_started or GameManager.is_game_over:
		return
	_game_started = true
	wave_spawner.call("start_next_wave")

func _restart_game() -> void:
	get_tree().paused = false
	GameManager.reset_game()
	get_tree().reload_current_scene()

## ---- 地图绘制 ----

func _draw() -> void:
	_draw_grid()
	_draw_path()
	_draw_hover()

func _draw_grid() -> void:
	# 绘制网格线
	for col in range(GameManager.GRID_COLS + 1):
		var x := col * GameManager.CELL_SIZE
		draw_line(Vector2(x, 0), Vector2(x, GameManager.GRID_ROWS * GameManager.CELL_SIZE),
				  Color(0.25, 0.25, 0.25, 0.3), 1.0)
	for row in range(GameManager.GRID_ROWS + 1):
		var y := row * GameManager.CELL_SIZE
		draw_line(Vector2(0, y), Vector2(GameManager.GRID_COLS * GameManager.CELL_SIZE, y),
				  Color(0.25, 0.25, 0.25, 0.3), 1.0)

func _draw_path() -> void:
	# 绘制路径格子
	for cell in GameManager.path_cells:
		var rect := Rect2(
			cell.x * GameManager.CELL_SIZE,
			cell.y * GameManager.CELL_SIZE,
			GameManager.CELL_SIZE,
			GameManager.CELL_SIZE
		)
		draw_rect(rect, Color(0.35, 0.28, 0.2))  # 泥土色路径

	# 绘制路径点连线（辅助线）
	if GameManager.path_points.size() > 1:
		for i in range(GameManager.path_points.size() - 1):
			draw_line(GameManager.path_points[i], GameManager.path_points[i + 1],
					  Color(0.5, 0.4, 0.25, 0.6), 3.0)

func _draw_hover() -> void:
	# 鼠标悬停高亮
	if _hover_cell.x < 0 or _hover_cell.y < 0:
		return

	var can_place := GameManager.can_place_tower(_hover_cell.x, _hover_cell.y)
	var can_afford := GameManager.gold >= GameManager.get_tower_cost(GameManager.selected_tower_type)
	var color := Color(0.2, 0.9, 0.2, 0.3) if can_place and can_afford else Color(0.9, 0.2, 0.2, 0.3)

	var rect := Rect2(
		_hover_cell.x * GameManager.CELL_SIZE,
		_hover_cell.y * GameManager.CELL_SIZE,
		GameManager.CELL_SIZE,
		GameManager.CELL_SIZE
	)
	draw_rect(rect, color)

	if _selected_cell.x >= 0:
		var selected_rect := Rect2(
			_selected_cell.x * GameManager.CELL_SIZE + 3,
			_selected_cell.y * GameManager.CELL_SIZE + 3,
			GameManager.CELL_SIZE - 6,
			GameManager.CELL_SIZE - 6
		)
		draw_rect(selected_rect, Color(1.0, 0.95, 0.35, 0.9), false, 3.0)

## ---- 游戏结束 ----

func _on_game_over() -> void:
	get_tree().paused = true

func _on_all_waves_completed() -> void:
	# 胜利！
	GameManager.is_game_over = true
	hud.call("show_message", "恭喜通关！", true)
