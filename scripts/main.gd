## 主场景脚本
## 处理地图绘制、植物放置输入、游戏流程
class_name GameMain
extends Node2D

## 提前催下一波的阳光奖励（用准备时间换资源）
const EARLY_WAVE_BONUS := 15

## ---- 预加载 ----
var _tower_scene: PackedScene = preload("res://scenes/tower.tscn")
var _hit_effect_scene: PackedScene = preload("res://scenes/hit_effect.tscn")
var _floating_text_scene: PackedScene = preload("res://scenes/floating_text.tscn")
var _particle_burst_scene: PackedScene = preload("res://scenes/particle_burst.tscn")

## ---- 节点引用 ----
@onready var towers_container: Node2D = $Towers
@onready var enemies_container: Node2D = $Enemies
@onready var projectiles_container: Node2D = $Projectiles
@onready var wave_spawner: WaveSpawner = $WaveSpawner
@onready var hud: GameHUD = $HUD
@onready var effects_container: Node2D = $Effects

## ---- 状态 ----
var _hover_cell: Vector2i = Vector2i(-1, -1)  # 鼠标悬停的格子
var _game_started: bool = false
var _selected_tower: Tower = null
var _selected_cell: Vector2i = Vector2i(-1, -1)
var _tutorial_active: bool = true
var _tutorial_first_tower_built: bool = false
var _recommended_cells: Array[Vector2i] = []
var _map_background_texture: Texture2D = null
var _map_background_path: String = ""

## ---- 生命周期 ----
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_gameplay_nodes_pausable()
	_setup_render_order()
	_setup_ambiance()
	# 连接信号
	GameManager.game_over.connect(_on_game_over)
	GameManager.life_lost.connect(_on_life_lost)
	GameManager.enemy_killed.connect(_on_enemy_killed)
	wave_spawner.connect("all_waves_completed", _on_all_waves_completed)
	_init_tutorial()
	queue_redraw()

## 按关卡设置整体光照氛围（CanvasModulate 只作用于 2D 世界，不影响 HUD）
func _setup_ambiance() -> void:
	var ambiance := CanvasModulate.new()
	ambiance.color = GameManager.get_level_ambient_color()
	add_child(ambiance)

## 渲染顺序：塔与敌人按 Y 轴跨容器排序（靠下者绘制在前），
## 子弹与特效用更高 z 始终置顶，地图保持在最底层
func _setup_render_order() -> void:
	y_sort_enabled = true
	towers_container.y_sort_enabled = true
	enemies_container.y_sort_enabled = true
	projectiles_container.z_index = 5
	effects_container.z_index = 6

## ---- 世界特效 ----

func _on_enemy_killed(world_pos: Vector2, reward: int, color: Color) -> void:
	_spawn_floating_text(world_pos + Vector2(0, -20), "+%d" % reward, Color(1.0, 0.88, 0.3))
	_spawn_particle_burst(world_pos, color, 14, 150.0, 6.0, 0.5)

func _spawn_floating_text(world_pos: Vector2, text: String, color: Color) -> void:
	var node := _floating_text_scene.instantiate() as FloatingText
	node.global_position = world_pos
	effects_container.add_child(node)
	node.setup(text, color)

func _spawn_particle_burst(world_pos: Vector2, color: Color, amount: int, speed: float, particle_size: float, life: float) -> void:
	var burst := _particle_burst_scene.instantiate() as ParticleBurst
	burst.global_position = world_pos
	effects_container.add_child(burst)
	burst.setup(color, amount, speed, particle_size, life)

func _set_gameplay_nodes_pausable() -> void:
	for node in [towers_container, enemies_container, projectiles_container, effects_container, wave_spawner]:
		node.process_mode = Node.PROCESS_MODE_PAUSABLE

func _init_tutorial() -> void:
	_tutorial_active = true
	_tutorial_first_tower_built = false
	_recommended_cells = _find_recommended_build_cells()
	hud.show_message("先在高亮绿色格子种一株豌豆射手，再点击开始", true)

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
		if event.keycode == KEY_F11:
			_toggle_fullscreen()
			return
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
		_on_start_wave_button()

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_on_start_wave_button()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			_select_tower_type_by_index(event.keycode - KEY_1)
		elif event.keycode == KEY_U:
			_upgrade_selected_tower()
		elif event.keycode == KEY_X:
			_sell_selected_tower()
		elif event.keycode == KEY_F:
			GameManager.cycle_game_speed()
		elif event.keycode == KEY_T:
			_cycle_selected_tower_priority()
		elif event.keycode == KEY_M:
			_toggle_mute()
		elif event.keycode == KEY_R:
			_restart_game()

## ---- 植物放置 ----

func _try_place_tower() -> void:
	var col := _hover_cell.x
	var row := _hover_cell.y

	var existing_tower := GameManager.get_tower_at(col, row) as Tower
	if existing_tower:
		_select_existing_tower(existing_tower, Vector2i(col, row))
		return

	if GameManager.try_place_tower(col, row, GameManager.selected_tower_type):
		var tower := _tower_scene.instantiate() as Tower
		tower.setup(GameManager.selected_tower_type, Vector2i(col, row))
		tower.global_position = GameManager.grid_to_pixel(col, row)
		towers_container.add_child(tower)
		GameManager.register_tower(col, row, tower)
		_select_existing_tower(tower, Vector2i(col, row))
		_on_tutorial_tower_built()
		queue_redraw()
	else:
		hud.show_message(_get_place_error_message(col, row))

func _get_place_error_message(col: int, row: int) -> String:
	var cell := Vector2i(col, row)
	if col < 0 or col >= GameManager.GRID_COLS or row < 0 or row >= GameManager.GRID_ROWS:
		return "不能在地图外种植"
	if cell in GameManager.path_cells:
		return "僵尸道路上不能种植"
	if cell in GameManager.occupied_cells:
		return "这里已经有植物了"

	var cost := GameManager.get_tower_cost(GameManager.selected_tower_type)
	if GameManager.gold < cost:
		return "阳光不足，需要 %d" % cost

	return "这里不能种植"

## 数字键按顺序选择植物（1→第 1 种，以此类推），越界忽略
func _select_tower_type_by_index(index: int) -> void:
	var types := GameManager.get_tower_types()
	if index >= 0 and index < types.size():
		_select_tower_type(types[index])

func _select_tower_type(tower_type: String) -> void:
	GameManager.set_selected_tower_type(tower_type)
	_set_selected_tower(null)
	_selected_cell = Vector2i(-1, -1)
	hud.show_tower_details(null)
	queue_redraw()

func _select_existing_tower(tower: Tower, cell: Vector2i) -> void:
	_set_selected_tower(tower)
	_selected_cell = cell
	hud.show_tower_details(tower)
	queue_redraw()

## 切换当前选中的植物，并同步自身的选中态（仅选中植物绘制射程圈）
func _set_selected_tower(tower: Tower) -> void:
	if _selected_tower and is_instance_valid(_selected_tower) and _selected_tower != tower:
		_selected_tower.set_selected(false)
	_selected_tower = tower
	if tower and is_instance_valid(tower):
		tower.set_selected(true)

func _upgrade_selected_tower() -> void:
	if not _selected_tower or not is_instance_valid(_selected_tower):
		hud.show_message("先点击选择一株植物")
		return
	if not _selected_tower.can_upgrade():
		hud.show_message("这株植物已经满级")
		return

	var cost := int(_selected_tower.get_upgrade_cost())
	if not GameManager.spend_gold(cost):
		hud.show_message("阳光不足，升级需要 %d" % cost)
		return

	_selected_tower.upgrade()
	GameManager.request_sfx("upgrade")
	hud.show_tower_details(_selected_tower)
	queue_redraw()

func _cycle_selected_tower_priority() -> void:
	if not _selected_tower or not is_instance_valid(_selected_tower):
		hud.show_message("先点击选择一株植物")
		return
	_selected_tower.cycle_target_priority()
	hud.show_tower_details(_selected_tower)
	hud.show_message("目标优先级：%s" % String(_selected_tower.get_target_priority_label()))

func _sell_selected_tower() -> void:
	if not _selected_tower or not is_instance_valid(_selected_tower):
		hud.show_message("先点击选择一株植物")
		return

	var refund := int(_selected_tower.get_sell_value())
	GameManager.add_gold(refund)
	GameManager.request_sfx("sell")
	GameManager.remove_tower(_selected_cell.x, _selected_cell.y)
	_selected_tower.queue_free()
	_selected_tower = null
	_selected_cell = Vector2i(-1, -1)
	hud.show_tower_details(null)
	hud.show_message("铲除成功，返还 %d 阳光" % refund)
	queue_redraw()

## 顶部"开始/催下一波"按钮（及空格/右键）的统一入口：未开局则开局，
## 开局后若处于波间窗口则提前催下一波
func _on_start_wave_button() -> void:
	if not _game_started:
		_start_game()
	else:
		_request_next_wave()

func _start_game() -> void:
	if _game_started or GameManager.is_game_over:
		return
	_tutorial_active = false
	hud.hide_overlay()
	_game_started = true
	hud.set_start_wave_available(false)
	hud.set_pause_button_paused(false)
	wave_spawner.start_next_wave()
	queue_redraw()

## 提前开始下一波：成功则奖励少量阳光（用准备时间换资源）
func _request_next_wave() -> void:
	if wave_spawner.request_next_wave_now():
		GameManager.add_gold(EARLY_WAVE_BONUS)
		GameManager.request_sfx("wave")
		hud.set_can_call_next_wave(false)
		hud.show_message("提前迎战！阳光 +%d" % EARLY_WAVE_BONUS)

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
	hud.hide_overlay()
	hud.set_start_wave_available(true)
	hud.set_pause_button_paused(false)
	queue_redraw()

func _on_tutorial_tower_built() -> void:
	if not _tutorial_active or _tutorial_first_tower_built:
		return
	_tutorial_first_tower_built = true
	hud.show_message("很好。可以再补一株植物，或点击顶部“开始”迎战第一波", true)
	queue_redraw()

func _toggle_pause() -> void:
	if GameManager.is_game_over or not _game_started:
		return
	var tree := get_tree()
	tree.paused = not tree.paused
	if tree.paused:
		hud.show_pause_screen()
	else:
		hud.hide_pause_screen()

## 静音开关：经 GameManager 切换并持久化（音效与音乐同时生效）
func _toggle_mute() -> void:
	GameManager.toggle_mute()
	hud.show_message("已静音" if GameManager.is_muted else "已取消静音")

## 全屏开关（F11）
func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

## ---- 地图绘制 ----

func _draw() -> void:
	# 地图整体下移，避免与顶部信息栏重叠（植物/僵尸/路径点已在 GameManager 中带上同样偏移）
	draw_set_transform(Vector2(0, GameManager.MAP_OFFSET_Y))
	_draw_background()
	_draw_buildable_cells()
	_draw_tutorial_recommendations()
	_draw_grid()
	_draw_path()
	_draw_hover()
	_draw_selected_cell()

func _draw_background() -> void:
	var map_size := Vector2(GameManager.GRID_COLS * GameManager.CELL_SIZE, GameManager.GRID_ROWS * GameManager.CELL_SIZE)
	var map_texture := _get_map_background_texture()
	if map_texture:
		draw_texture_rect(map_texture, Rect2(Vector2.ZERO, map_size), false)
		return

	var background_color := GameManager.get_level_background_color()
	draw_rect(Rect2(Vector2.ZERO, map_size), background_color)

	for row in range(GameManager.GRID_ROWS):
		for col in range(GameManager.GRID_COLS):
			var cell_origin := Vector2(col * GameManager.CELL_SIZE, row * GameManager.CELL_SIZE)
			var tint := background_color.lightened(0.08) if (col + row) % 2 == 0 else background_color.darkened(0.06)
			tint.a = 0.45
			draw_rect(Rect2(cell_origin, Vector2(GameManager.CELL_SIZE, GameManager.CELL_SIZE)), tint)

	_draw_ground_details(background_color)

func _get_map_background_texture() -> Texture2D:
	var path := GameManager.get_level_background_image_path()
	if path.is_empty():
		return null
	if _map_background_texture and _map_background_path == path:
		return _map_background_texture
	if not FileAccess.file_exists(path):
		return null

	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null

	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null

	_map_background_texture = ImageTexture.create_from_image(image)
	_map_background_path = path
	return _map_background_texture

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

## 是否使用了关卡背景图（缓存命中，开销可忽略）
func _has_background_image() -> bool:
	return _get_map_background_texture() != null

func _draw_buildable_cells() -> void:
	var buildable_color := GameManager.get_level_buildable_color()
	# 有背景图时只描边、不铺色，避免遮住美术
	var fill := not _has_background_image()
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
			if fill:
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
	# 有背景图时不画网格线，避免在美术上叠加"线框"观感
	if _has_background_image():
		return
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

	# 绘制路径点连线（辅助线）：_draw 已施加 MAP_OFFSET_Y 变换，这里用局部坐标
	# 直接绘制，与地图格子同一坐标系，无需再做偏移加减
	var points := GameManager.path_points_local
	if points.size() > 1:
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], path_color.lightened(0.22), 4.0)

		_draw_start_marker(points[0])
		_draw_goal_marker(points[points.size() - 1])

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

## 鼠标悬停高亮：仅在地图格子范围内显示，避免鼠标移到顶部/底部 UI 区域时出现红色提示框
func _draw_hover() -> void:
	var in_bounds := _hover_cell.x >= 0 and _hover_cell.y >= 0 \
		and _hover_cell.x < GameManager.GRID_COLS and _hover_cell.y < GameManager.GRID_ROWS
	if not in_bounds:
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

	# 种植前射程预览：悬停可种植格子时，画出所选植物的攻击范围圈
	if can_place:
		var center := Vector2(
			_hover_cell.x * GameManager.CELL_SIZE + GameManager.CELL_SIZE * 0.5,
			_hover_cell.y * GameManager.CELL_SIZE + GameManager.CELL_SIZE * 0.5
		)
		var preview_range := float(GameManager.get_tower_config(GameManager.selected_tower_type)["range"])
		draw_circle(center, preview_range, Color(0.4, 0.8, 1.0, 0.07))
		draw_arc(center, preview_range, 0, TAU, 48, Color(0.45, 0.8, 1.0, 0.55), 1.5)

## 已选中格子的黄色描边（与悬停高亮相互独立，可同时出现）
func _draw_selected_cell() -> void:
	if _selected_cell.x < 0:
		return
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
	var effect := _hit_effect_scene.instantiate() as HitEffect
	effects_container.add_child(effect)
	effect.setup(GameManager.path_points[GameManager.path_points.size() - 1], Color(1.0, 0.15, 0.12), 42.0)
	hud.flash_damage()
	hud.show_message("僵尸突破防线，生命 -1")

func _on_all_waves_completed() -> void:
	# 胜利！
	GameManager.win_game()
	get_tree().paused = true
