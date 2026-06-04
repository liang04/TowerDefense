## 主场景脚本
## 处理地图绘制、塔放置输入、游戏流程
extends Node2D

## ---- 预加载 ----
var _tower_scene: PackedScene = preload("res://scenes/tower.tscn")
var _hit_effect_scene: PackedScene = preload("res://scenes/hit_effect.tscn")

## ---- 节点引用 ----
@onready var towers_container: Node2D = $Towers
@onready var enemies_container: Node2D = $Enemies
@onready var projectiles_container: Node2D = $Projectiles
@onready var wave_spawner: Node = $WaveSpawner
@onready var hud: Node = $HUD
@onready var effects_container: Node2D = $Effects

## ---- 状态 ----
var _hover_cell: Vector2i = Vector2i(-1, -1)  # 鼠标悬停的格子
var _game_started: bool = false
var _selected_tower: Node = null
var _selected_cell: Vector2i = Vector2i(-1, -1)
var _tutorial_active: bool = true
var _tutorial_first_tower_built: bool = false
var _recommended_cells: Array[Vector2i] = []

## ---- 生命周期 ----
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_gameplay_nodes_pausable()
	# 连接信号
	GameManager.game_over.connect(_on_game_over)
	GameManager.life_lost.connect(_on_life_lost)
	wave_spawner.connect("all_waves_completed", _on_all_waves_completed)
	_init_tutorial()
	queue_redraw()

func _set_gameplay_nodes_pausable() -> void:
	for node in [towers_container, enemies_container, projectiles_container, effects_container, wave_spawner]:
		node.process_mode = Node.PROCESS_MODE_PAUSABLE

func _init_tutorial() -> void:
	_tutorial_active = true
	_tutorial_first_tower_built = false
	_recommended_cells = _find_recommended_build_cells()
	hud.call("show_message", "先在高亮绿色格子建一座箭塔，再点击开始", true)

func _find_recommended_build_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var candidates: Array[Vector2i] = []
	var seen: Dictionary = {}
	var directions := [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]

	for path_cell in GameManager.path_cells.keys():
		for direction in directions:
			var cell: Vector2i = path_cell + direction
			if cell in seen or not GameManager.can_place_tower(cell.x, cell.y):
				continue
			seen[cell] = true
			candidates.append(cell)

	var map_center := Vector2(GameManager.GRID_COLS - 1, GameManager.GRID_ROWS - 1) * 0.5
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var distance_a := Vector2(a).distance_to(map_center)
		var distance_b := Vector2(b).distance_to(map_center)
		return distance_a < distance_b
	)

	for cell in candidates:
		result.append(cell)
		if result.size() >= 3:
			break
	return result

func _process(_delta: float) -> void:
	# 更新悬停格子
	var mouse_pos := get_global_mouse_position()
	var new_hover := GameManager.pixel_to_grid(mouse_pos)
	if new_hover != _hover_cell:
		_hover_cell = new_hover
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			_toggle_pause()
			return
		if get_tree().paused:
			return
	elif get_tree().paused:
		return

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
		elif event.keycode == KEY_R:
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
		_on_tutorial_tower_built()
		queue_redraw()
	else:
		hud.call("show_message", _get_place_error_message(col, row))

func _get_place_error_message(col: int, row: int) -> String:
	var cell := Vector2i(col, row)
	if col < 0 or col >= GameManager.GRID_COLS or row < 0 or row >= GameManager.GRID_ROWS:
		return "不能在地图外建塔"
	if cell in GameManager.path_cells:
		return "道路上不能建塔"
	if cell in GameManager.occupied_cells:
		return "这里已经有塔了"

	var cost := GameManager.get_tower_cost(GameManager.selected_tower_type)
	if GameManager.gold < cost:
		return "金币不足，需要 %d" % cost

	return "这里不能建塔"

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
	GameManager.request_sfx("upgrade")
	hud.call("show_tower_details", _selected_tower)
	queue_redraw()

func _sell_selected_tower() -> void:
	if not _selected_tower or not is_instance_valid(_selected_tower):
		hud.call("show_message", "先点击选择一座塔")
		return

	var refund := int(_selected_tower.call("get_sell_value"))
	GameManager.add_gold(refund)
	GameManager.request_sfx("sell")
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
	_tutorial_active = false
	hud.call("hide_overlay")
	_game_started = true
	hud.call("set_start_wave_available", false)
	hud.call("set_pause_button_paused", false)
	wave_spawner.call("start_next_wave")
	queue_redraw()

func _restart_game() -> void:
	get_tree().paused = false
	GameManager.reset_game()
	get_tree().reload_current_scene()

func _reload_scene_for_level() -> void:
	var tree := get_tree()
	tree.paused = false
	if tree.current_scene:
		tree.reload_current_scene()
		return

	_game_started = false
	_selected_tower = null
	_selected_cell = Vector2i(-1, -1)
	_init_tutorial()
	hud.call("hide_overlay")
	hud.call("set_start_wave_available", true)
	hud.call("set_pause_button_paused", false)
	queue_redraw()

func _on_tutorial_tower_built() -> void:
	if not _tutorial_active or _tutorial_first_tower_built:
		return
	_tutorial_first_tower_built = true
	hud.call("show_message", "很好。可以再补一座塔，或点击顶部“开始”迎战第一波", true)
	queue_redraw()

func _toggle_pause() -> void:
	if GameManager.is_game_over or not _game_started:
		return
	var tree := get_tree()
	tree.paused = not tree.paused
	if tree.paused:
		hud.call("show_pause_screen")
	else:
		hud.call("hide_pause_screen")

## ---- 地图绘制 ----

func _draw() -> void:
	_draw_background()
	_draw_buildable_cells()
	_draw_tutorial_recommendations()
	_draw_grid()
	_draw_path()
	_draw_hover()

func _draw_background() -> void:
	var map_size := Vector2(GameManager.GRID_COLS * GameManager.CELL_SIZE, GameManager.GRID_ROWS * GameManager.CELL_SIZE)
	var background_color := GameManager.get_level_background_color()
	draw_rect(Rect2(Vector2.ZERO, map_size), background_color)

	for row in range(GameManager.GRID_ROWS):
		for col in range(GameManager.GRID_COLS):
			var cell_origin := Vector2(col * GameManager.CELL_SIZE, row * GameManager.CELL_SIZE)
			var tint := background_color.lightened(0.08) if (col + row) % 2 == 0 else background_color.darkened(0.06)
			tint.a = 0.45
			draw_rect(Rect2(cell_origin, Vector2(GameManager.CELL_SIZE, GameManager.CELL_SIZE)), tint)

	# 固定装饰点，避免运行时随机导致地图闪烁。
	var decorations := [
		Vector2(1.4, 5.8), Vector2(2.3, 6.8), Vector2(4.8, 0.8),
		Vector2(5.2, 2.0), Vector2(8.6, 6.2), Vector2(10.5, 4.2),
		Vector2(11.2, 0.7), Vector2(0.6, 3.8)
	]
	for i in range(decorations.size()):
		var pos: Vector2 = decorations[i] * GameManager.CELL_SIZE
		if i % 3 == 0:
			draw_circle(pos, 10.0, Color(0.07, 0.13, 0.08, 0.65))
			draw_circle(pos + Vector2(7, -3), 7.0, Color(0.08, 0.16, 0.09, 0.55))
		else:
			draw_circle(pos, 6.0, Color(0.18, 0.18, 0.16, 0.6))
			draw_circle(pos + Vector2(5, 4), 4.0, Color(0.1, 0.1, 0.09, 0.55))

func _draw_buildable_cells() -> void:
	var buildable_color := GameManager.get_level_buildable_color()
	for row in range(GameManager.GRID_ROWS):
		for col in range(GameManager.GRID_COLS):
			var cell := Vector2i(col, row)
			if cell in GameManager.path_cells or cell in GameManager.occupied_cells:
				continue

			var rect := Rect2(
				col * GameManager.CELL_SIZE + 8,
				row * GameManager.CELL_SIZE + 8,
				GameManager.CELL_SIZE - 16,
				GameManager.CELL_SIZE - 16
			)
			draw_rect(rect, buildable_color)
			draw_rect(rect, Color(0.37, 0.85, 0.42, 0.28), false, 1.0)

func _draw_tutorial_recommendations() -> void:
	if not _tutorial_active or _tutorial_first_tower_built:
		return

	for cell in _recommended_cells:
		if not GameManager.can_place_tower(cell.x, cell.y):
			continue

		var center := GameManager.grid_to_pixel(cell.x, cell.y)
		var rect := Rect2(
			cell.x * GameManager.CELL_SIZE + 6,
			cell.y * GameManager.CELL_SIZE + 6,
			GameManager.CELL_SIZE - 12,
			GameManager.CELL_SIZE - 12
		)
		draw_rect(rect, Color(0.35, 1.0, 0.32, 0.3))
		draw_rect(rect, Color(0.9, 1.0, 0.35, 0.9), false, 3.0)
		draw_circle(center, 6.0, Color(1.0, 0.95, 0.25, 0.95))

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
	var path_color := GameManager.get_level_path_color()
	# 绘制路径格子
	for cell in GameManager.path_cells:
		var rect := Rect2(
			cell.x * GameManager.CELL_SIZE,
			cell.y * GameManager.CELL_SIZE,
			GameManager.CELL_SIZE,
			GameManager.CELL_SIZE
		)
		draw_rect(rect, path_color)
		draw_rect(rect.grow(-3), path_color.lightened(0.16), false, 2.0)

	# 绘制路径点连线（辅助线）
	if GameManager.path_points.size() > 1:
		for i in range(GameManager.path_points.size() - 1):
			draw_line(GameManager.path_points[i], GameManager.path_points[i + 1],
					  Color(0.5, 0.4, 0.25, 0.6), 3.0)

		var start_point := GameManager.path_points[0]
		var end_point := GameManager.path_points[GameManager.path_points.size() - 1]
		draw_circle(start_point, 14.0, Color(0.3, 0.8, 0.35, 0.95))
		draw_circle(end_point, 16.0, Color(0.9, 0.2, 0.18, 0.95))
		draw_arc(end_point, 24.0, 0.0, TAU, 32, Color(1.0, 0.35, 0.25, 0.75), 3.0)

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

func _on_life_lost(_new_lives: int) -> void:
	if GameManager.path_points.is_empty():
		return
	var effect := _hit_effect_scene.instantiate()
	effects_container.add_child(effect)
	effect.call("setup", GameManager.path_points[GameManager.path_points.size() - 1], Color(1.0, 0.15, 0.12), 42.0)
	hud.call("show_message", "敌人突破防线，生命 -1")

func _on_all_waves_completed() -> void:
	# 胜利！
	GameManager.win_game()
	get_tree().paused = true
