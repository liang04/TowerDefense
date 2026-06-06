## 防御塔脚本
## 自动攻击范围内最近的敌人
class_name Tower
extends Node2D

var _projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")
var _particle_burst_scene: PackedScene = preload("res://scenes/particle_burst.tscn")

const TOWER_ART_PATHS := {
	"arrow": "res://assets/towers/arrow_tower.svg",
	"cannon": "res://assets/towers/cannon_tower.svg",
	"frost": "res://assets/towers/frost_tower.svg",
}
static var _tower_art_textures: Dictionary = {}

## ---- 属性 ----
var tower_type: String = "arrow"
var tower_name: String = "豌豆射手"
var level: int = 1
var max_level: int = 3
var grid_cell: Vector2i = Vector2i.ZERO
var total_spent: int = 0
var attack_damage: int = 10
var attack_range: float = 160.0   # 像素
var attack_cooldown: float = 1.0  # 秒
var slow_multiplier: float = 1.0
var slow_duration: float = 0.0
var splash_radius: float = 0.0
var body_color: Color = Color(0.2, 0.45, 0.95)

## 目标重选间隔（秒）：避免每帧对全体敌人做一次全量扫描
const TARGET_SCAN_INTERVAL := 0.1

## 可选的目标优先级，按顺序循环切换
const TARGET_PRIORITIES: Array[String] = ["progress", "nearest", "strongest", "fastest"]
const TARGET_PRIORITY_LABELS := {
	"progress": "前排",
	"nearest": "最近",
	"strongest": "最血",
	"fastest": "最快",
}

## ---- 内部状态 ----
var _cooldown_timer: float = 0.0
var _current_target: Enemy = null
var _shot_flash_timer: float = 0.0
var _scan_timer: float = 0.0
var _selected: bool = false
var _projectiles_container: Node = null
var target_priority: String = "progress"
var _anim: AnimatedSprite2D = null
var _use_sprite: bool = false

## ---- 生命周期 ----
func _ready() -> void:
	_apply_config()
	add_child(SpriteLibrary.make_shadow(20.0, 8.0, 22.0))
	_setup_sprite()

## 若存在对应 PNG 帧则用 AnimatedSprite2D 渲染，否则回退到 _draw()
func _setup_sprite() -> void:
	var frames := SpriteLibrary.build_tower_frames(tower_type)
	if frames == null:
		return
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = frames
	_anim.scale = Vector2.ONE * SpriteLibrary.get_tower_scale(tower_type)
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# 置于父节点之后绘制，使等级点/射程圈/攻击线叠加在精灵之上
	_anim.show_behind_parent = true
	add_child(_anim)
	_anim.play(SpriteLibrary.ANIM_NAME)
	var frame_count := frames.get_frame_count(SpriteLibrary.ANIM_NAME)
	if frame_count > 1:
		_anim.frame = randi() % frame_count
		_anim.frame_progress = randf()
	_use_sprite = true
	queue_redraw()

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

	if _use_sprite:
		_anim.modulate = Color(1.5, 1.4, 0.9) if _shot_flash_timer > 0.0 else Color.WHITE

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
	var best_target: Enemy = null
	var best_score: float = -INF
	var best_distance: float = INF

	for node in get_tree().get_nodes_in_group("enemies"):
		if not (node is Enemy):
			continue

		var enemy := node as Enemy
		var distance := global_position.distance_to(enemy.global_position)
		if distance > attack_range:
			continue

		# 同分时一律取更近的目标作为决胜
		var score := _priority_score(enemy, distance)
		if score > best_score or (is_equal_approx(score, best_score) and distance < best_distance):
			best_score = score
			best_distance = distance
			best_target = enemy

	_current_target = best_target

## 根据当前优先级为候选敌人打分，分数越高越优先
func _priority_score(enemy: Enemy, distance: float) -> float:
	match target_priority:
		"nearest":
			return -distance
		"strongest":
			return float(enemy.hp)
		"fastest":
			return enemy.speed
		_:  # progress：路径进度最远（默认）
			return enemy.get_path_progress()

## 循环切换目标优先级，并立即按新优先级重选目标
func cycle_target_priority() -> void:
	var index := TARGET_PRIORITIES.find(target_priority)
	target_priority = TARGET_PRIORITIES[(index + 1) % TARGET_PRIORITIES.size()]
	_select_target()
	queue_redraw()

func get_target_priority_label() -> String:
	return String(TARGET_PRIORITY_LABELS.get(target_priority, "前排"))

func _attack(target: Enemy) -> void:
	if not is_instance_valid(target):
		return

	var projectiles_container := _get_projectiles_container()
	if projectiles_container == null:
		return

	var projectile := _projectile_scene.instantiate() as Projectile
	projectiles_container.add_child(projectile)
	projectile.setup(global_position, target, attack_damage, slow_multiplier, slow_duration, body_color, splash_radius)
	_spawn_muzzle_flash(projectiles_container, target)
	GameManager.request_sfx("shoot")
	_shot_flash_timer = 0.12

## 朝目标方向喷出一小簇枪口火光粒子
func _spawn_muzzle_flash(container: Node, target: Enemy) -> void:
	var direction := (target.global_position - global_position).normalized()
	var burst := _particle_burst_scene.instantiate() as ParticleBurst
	burst.global_position = global_position + direction * 18.0
	container.add_child(burst)
	burst.setup(body_color.lightened(0.35), 6, 120.0, 3.0, 0.22, direction, 24.0)

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
	var stats := GameManager.get_scaled_tower_stats(tower_type, level)

	tower_name = String(config["name"])
	attack_damage = int(stats["damage"])
	attack_range = float(stats["range"])
	attack_cooldown = float(stats["cooldown"])
	slow_multiplier = float(stats["slow_multiplier"])
	slow_duration = float(stats["slow_duration"])
	splash_radius = float(stats["splash_radius"])
	var color_value = config["color"]
	if color_value is Color:
		body_color = color_value

	queue_redraw()

## ---- 绘制美术资源与攻击提示 ----
func _draw() -> void:
	# 精灵模式由 AnimatedSprite2D 绘制本体，这里只补充等级点/射程圈/攻击线
	if not _use_sprite:
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
