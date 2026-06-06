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
		elif event.keycode == KEY_F:
			GameManager.cycle_game_speed()
		elif event.keycode == KEY_T:
			_cycle_selected_tower_priority()
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
	_set_selected_tower(null)
	_selected_cell = Vector2i(-1, -1)
	hud.call("show_tower_details", null)
	queue_redraw()

func _select_existing_tower(tower: Node, cell: Vector2i) -> void:
	_set_selected_tower(tower)
	_selected_cell = cell
	hud.call("show_tower_details", tower)
	queue_redraw()

## 切换当前选中的塔，并同步塔自身的选中态（仅选中塔绘制射程圈）
func _set_selected_tower(tower: Node) -> void:
	if _selected_tower and is_instance_valid(_selected_tower) and _selected_tower != tower:
		_selected_tower.call("set_selected", false)
	_selected_tower = tower
	if tower and is_instance_valid(tower):
		tower.call("set_selected", true)

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

func _cycle_selected_tower_priority() -> void:
	if not _selected_tower or not is_instance_valid(_selected_tower):
		hud.call("show_message", "先点击选择一座塔")
		return
	_selected_tower.call("cycle_target_priority")
	hud.call("show_tower_details", _selected_tower)
	hud.call("show_message", "目标优先级：%s" % String(_selected_tower.call("get_target_priority_label")))

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
	# 地图整体下移，避免与顶部信息栏重叠（塔/敌人/路径点已在 GameManager 中带上同样偏移）
	draw_set_transform(Vector2(0, GameManager.MAP_OFFSET_Y))
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

	_draw_ground_details(background_color)

func _draw_ground_details(background_color: Color) -> void:
	var grass_color := background_color.lightened(0.28)
	var dark_grass := background_color.darkened(0.18)
	var rock_color := Color(0.18, 0.18, 0.16, 0.58)
	var details := [
		{"cell": Vector2i(1, 5), "offset": Vector2(28, 42), "kind": "bush"},
		{"cell": Vector2i(2, 6), "offset": Vector2(20, 58), "kind": "rock"},
		{"cell": Vector2i(4, 0), "offset": Vector2(62, 62), "kind": "grass"},
		{"cell": Vector2i(5, 2), "offset": Vector2(18, 16), "kind": "bush"},
		{"cell": Vector2i(8, 6), "offset": Vector2(52, 16), "kind": "rock"},
		{"cell": Vector2i(10, 4), "offset": Vector2(36, 20), "kind": "rock"},
		{"cell": Vector2i(11, 0), "offset": Vector2(18, 54), "kind": "bush"},
		{"cell": Vector2i(0, 3), "offset": Vector2(50, 52), "kind": "grass"},
		{"cell": Vector2i(3, 6), "offset": Vector2(24, 26), "kind": "grass"},
		{"cell": Vector2i(9, 6), "offset": Vector2(52, 52), "kind": "bush"},
	]

	for detail in details:
		var cell: Vector2i = detail["cell"]
		if cell in GameManager.path_cells:
			continue

		var pos: Vector2 = Vector2(cell.x, cell.y) * GameManager.CELL_SIZE + detail["offset"]
		match String(detail["kind"]):
			"bush":
				draw_circle(pos, 10.0, dark_grass)
				draw_circle(pos + Vector2(7, -3), 7.0, grass_color.darkened(0.12))
				draw_circle(pos + Vector2(-6, 2), 6.0, grass_color.darkened(0.2))
			"rock":
				draw_circle(pos, 6.0, rock_color)
				draw_circle(pos + Vector2(5, 4), 4.0, rock_color.darkened(0.35))
			_:
				for blade in range(3):
					var x := float(blade * 5 - 5)
					draw_line(pos + Vector2(x, 5), pos + Vector2(x + 2, -5), grass_color, 1.6)

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

		# 这里在 _draw 的偏移变换内绘制，使用网格原始坐标即可（不能再叠加 grid_to_pixel 的偏移）
		var center := Vector2(
			cell.x * GameManager.CELL_SIZE + GameManager.CELL_SIZE * 0.5,
			cell.y * GameManager.CELL_SIZE + GameManager.CELL_SIZE * 0.5
		)
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
		draw_rect(rect, path_color.darkened(0.2))
		draw_rect(rect.grow(-4), path_color)
		draw_rect(rect.grow(-8), path_color.lightened(0.12), false, 1.5)
		_draw_path_cell_details(cell, path_color)

	# 绘制路径点连线（辅助线）
	# path_points 已带 MAP_OFFSET_Y，而 _draw 整体又施加了同样的偏移变换，
	# 这里减去一次，避免连线和起终点标记被二次下移。
	var offset := Vector2(0, GameManager.MAP_OFFSET_Y)
	if GameManager.path_points.size() > 1:
		for i in range(GameManager.path_points.size() - 1):
			draw_line(GameManager.path_points[i] - offset, GameManager.path_points[i + 1] - offset,
					  path_color.lightened(0.22), 4.0)

		var start_point := GameManager.path_points[0] - offset
		var end_point := GameManager.path_points[GameManager.path_points.size() - 1] - offset
		_draw_start_marker(start_point)
		_draw_goal_marker(end_point)

func _draw_path_cell_details(cell: Vector2i, path_color: Color) -> void:
	var base := Vector2(cell.x, cell.y) * GameManager.CELL_SIZE
	var seed := cell.x * 37 + cell.y * 53
	var pebble_color := path_color.lightened(0.25)
	var shadow_color := path_color.darkened(0.28)

	for i in range(2):
		var offset := Vector2(
			float(18 + ((seed + i * 19) % 43)),
			float(18 + ((seed * 3 + i * 23) % 42))
		)
		var pos := base + offset
		draw_circle(pos, 2.5, shadow_color)
		draw_circle(pos + Vector2(-1, -1), 1.6, pebble_color)

	for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbor: Vector2i = cell + direction
		if neighbor in GameManager.path_cells:
			continue

		if direction.x != 0:
			var x := base.x + (GameManager.CELL_SIZE if direction.x > 0 else 0)
			draw_line(Vector2(x, base.y + 6), Vector2(x, base.y + GameManager.CELL_SIZE - 6), path_color.lightened(0.18), 2.0)
		else:
			var y := base.y + (GameManager.CELL_SIZE if direction.y > 0 else 0)
			draw_line(Vector2(base.x + 6, y), Vector2(base.x + GameManager.CELL_SIZE - 6, y), path_color.lightened(0.18), 2.0)

func _draw_start_marker(start_point: Vector2) -> void:
	draw_circle(start_point, 18.0, Color(0.08, 0.28, 0.11, 0.95))
	draw_circle(start_point, 12.0, Color(0.32, 0.86, 0.38, 0.95))
	draw_line(start_point + Vector2(-18, 20), start_point + Vector2(18, 20), Color(0.08, 0.12, 0.08, 0.8), 4.0)
	draw_arc(start_point, 24.0, PI * 1.05, PI * 1.95, 24, Color(0.68, 1.0, 0.58, 0.75), 2.0)

func _draw_goal_marker(end_point: Vector2) -> void:
	var base := Rect2(end_point - Vector2(22, 18), Vector2(44, 36))
	draw_rect(base, Color(0.35, 0.08, 0.07, 0.95))
	draw_rect(base.grow(-5), Color(0.9, 0.22, 0.16, 0.95))
	draw_rect(Rect2(end_point + Vector2(-7, -3), Vector2(14, 21)), Color(0.12, 0.04, 0.04, 0.85))
	draw_arc(end_point, 28.0, 0.0, TAU, 32, Color(1.0, 0.38, 0.25, 0.75), 3.0)

func _draw_hover() -> void:
	# 鼠标悬停高亮：仅在地图格子范围内显示，避免鼠标移到顶部/底部 UI 区域时出现红色提示框
	var in_bounds := _hover_cell.x >= 0 and _hover_cell.y >= 0 \
		and _hover_cell.x < GameManager.GRID_COLS and _hover_cell.y < GameManager.GRID_ROWS
	if in_bounds:
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
