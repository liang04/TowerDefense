## 防御塔脚本
## 自动攻击范围内最近的敌人
extends Node2D

var _projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

const TOWER_ART_PATHS := {
	"arrow": "res://assets/towers/arrow_tower.svg",
	"cannon": "res://assets/towers/cannon_tower.svg",
	"frost": "res://assets/towers/frost_tower.svg",
}
static var _tower_art_textures: Dictionary = {}

## ---- 属性 ----
var tower_type: String = "arrow"
var tower_name: String = "箭塔"
var level: int = 1
var max_level: int = 3
var grid_cell: Vector2i = Vector2i.ZERO
var total_spent: int = 0
var attack_damage: int = 10
var attack_range: float = 160.0   # 像素
var attack_cooldown: float = 1.0  # 秒
var slow_multiplier: float = 1.0
var slow_duration: float = 0.0
var body_color: Color = Color(0.2, 0.45, 0.95)

## 目标重选间隔（秒）：避免每帧对全体敌人做一次全量扫描
const TARGET_SCAN_INTERVAL := 0.1

## ---- 内部状态 ----
var _cooldown_timer: float = 0.0
var _current_target: Node2D = null
var _shot_flash_timer: float = 0.0
var _scan_timer: float = 0.0
var _selected: bool = false
var _projectiles_container: Node = null

## ---- 生命周期 ----
func _ready() -> void:
	_apply_config()

func _process(delta: float) -> void:
	var was_flashing := _shot_flash_timer > 0.0
	var previous_target := _current_target

	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	_shot_flash_timer = maxf(_shot_flash_timer - delta, 0.0)
	_scan_timer = maxf(_scan_timer - delta, 0.0)

	# 清理已销毁的目标
	if _current_target and not is_instance_valid(_current_target):
		_current_target = null

	# 降频重选目标：每 TARGET_SCAN_INTERVAL 秒一次，而非每帧全量扫描
	if _scan_timer <= 0.0:
		_scan_timer = TARGET_SCAN_INTERVAL
		_select_target()

	# 攻击
	if _current_target and _cooldown_timer <= 0.0:
		_attack(_current_target)
		_cooldown_timer = attack_cooldown

	# 仅在需要时重绘：有目标（指示线跟随移动）/ 闪光仍在或刚结束 / 目标发生变化
	if _current_target or was_flashing or previous_target != _current_target:
		queue_redraw()

## 设置选中状态（由主场景调用），仅选中的塔绘制射程圈
func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	queue_redraw()

## ---- 内部方法 ----

func _select_target() -> void:
	var best_target: Node2D = null
	var best_progress: float = -INF
	var best_distance: float = INF

	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not (node is Node2D):
			continue

		var enemy := node as Node2D
		var distance := global_position.distance_to(enemy.global_position)
		if distance > attack_range:
			continue

		var progress := 0.0
		if enemy.has_method("get_path_progress"):
			progress = float(enemy.call("get_path_progress"))

		if progress > best_progress or (is_equal_approx(progress, best_progress) and distance < best_distance):
			best_progress = progress
			best_distance = distance
			best_target = enemy

	_current_target = best_target

func _attack(target: Node2D) -> void:
	if not is_instance_valid(target):
		return

	var projectiles_container := _get_projectiles_container()
	if projectiles_container == null:
		return

	var projectile := _projectile_scene.instantiate()
	projectiles_container.add_child(projectile)
	projectile.call("setup", global_position, target, attack_damage, slow_multiplier, slow_duration, body_color)
	GameManager.request_sfx("shoot")
	_shot_flash_timer = 0.12

func _get_projectiles_container() -> Node:
	if _projectiles_container and is_instance_valid(_projectiles_container):
		return _projectiles_container
	var current := get_parent()
	while current:
		var projectiles := current.get_node_or_null("Projectiles")
		if projectiles:
			_projectiles_container = projectiles
			return projectiles
		current = current.get_parent()
	return null

func _get_tower_art_texture() -> Texture2D:
	if tower_type in _tower_art_textures:
		return _tower_art_textures[tower_type]
	if not (tower_type in TOWER_ART_PATHS):
		return null

	var path := String(TOWER_ART_PATHS[tower_type])
	var svg_text := FileAccess.get_file_as_string(path)
	if svg_text.is_empty():
		return null

	var image := Image.new()
	var error := image.load_svg_from_string(svg_text)
	if error != OK:
		return null

	var texture := ImageTexture.create_from_image(image)
	_tower_art_textures[tower_type] = texture
	return texture

func setup(new_tower_type: String, new_grid_cell: Vector2i) -> void:
	tower_type = new_tower_type
	grid_cell = new_grid_cell
	level = 1
	total_spent = GameManager.get_tower_cost(tower_type)
	_apply_config()

func can_upgrade() -> bool:
	return level < max_level

func get_upgrade_cost() -> int:
	if not can_upgrade():
		return 0
	var base_cost := GameManager.get_tower_cost(tower_type)
	return int(round(float(base_cost) * (0.65 + float(level) * 0.35)))

func upgrade() -> bool:
	if not can_upgrade():
		return false
	var cost := get_upgrade_cost()
	level += 1
	total_spent += cost
	_apply_config()
	_shot_flash_timer = 0.2
	return true

func get_sell_value() -> int:
	return int(round(float(total_spent) * 0.6))

func get_display_name() -> String:
	return "%s Lv.%d" % [tower_name, level]

func get_stats_text() -> String:
	return GameManager.get_tower_stats_text(tower_type, level)

func _apply_config() -> void:
	var config := GameManager.get_tower_config(tower_type)
	var level_scale := 1.0 + float(level - 1) * 0.45
	var range_bonus := float(level - 1) * 14.0
	var cooldown_scale := 1.0 - float(level - 1) * 0.12

	tower_name = String(config["name"])
	attack_damage = int(round(float(config["damage"]) * level_scale))
	attack_range = float(config["range"]) + range_bonus
	attack_cooldown = maxf(float(config["cooldown"]) * cooldown_scale, 0.18)
	slow_multiplier = float(config["slow_multiplier"])
	slow_duration = float(config["slow_duration"])
	var color_value = config["color"]
	if color_value is Color:
		body_color = color_value

	queue_redraw()

## ---- 绘制美术资源与攻击提示 ----
func _draw() -> void:
	var draw_color := body_color if _shot_flash_timer <= 0.0 else Color(1.0, 0.9, 0.25)
	var art_texture := _get_tower_art_texture()
	if art_texture:
		var modulate := Color.WHITE if _shot_flash_timer <= 0.0 else Color(1.25, 1.15, 0.65)
		draw_texture_rect(art_texture, Rect2(-32, -34, 64, 64), false, modulate)
	else:
		draw_circle(Vector2.ZERO, 24.0, draw_color)

	draw_circle(Vector2(0, 0), 4.0 + float(level) * 2.0, Color(1, 1, 1, 0.78))

	# 射程圈只在塔被选中时绘制，避免每帧为所有塔绘制 64 段圆弧
	if _selected:
		draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(0.35, 0.55, 1.0, 0.18), 1.0)

	# 攻击指示线（指向当前目标）
	if _current_target and is_instance_valid(_current_target):
		var local_target := _current_target.global_position - global_position
		draw_line(Vector2.ZERO, local_target, Color(1, 1, 0.3, 0.7), 2.0)
