## 敌人脚本
## 沿 GameManager 中定义的路径点移动，到达终点扣玩家生命
class_name Enemy
extends Node2D

const ENEMY_ART_PATHS := {
	"grunt": "res://assets/enemies/grunt.svg",
	"runner": "res://assets/enemies/runner.svg",
	"tank": "res://assets/enemies/tank.svg",
}
static var _enemy_art_textures: Dictionary = {}

## ---- 属性 ----
var max_hp: int = 30
var hp: int = 30
var enemy_type: String = "grunt"
var speed: float = 120.0     # 像素/秒
var reward: int = 10         # 击杀金币奖励
var body_color: Color = Color(0.2, 0.8, 0.2)

## ---- 内部状态 ----
var _waypoints: PackedVector2Array = []
var _current_wp_index: int = 0
var _slow_timer: float = 0.0
var _slow_multiplier: float = 1.0
var _hit_flash_timer: float = 0.0

## ---- 生命周期 ----
func _ready() -> void:
	add_to_group("enemies")
	_waypoints = GameManager.path_points
	if _waypoints.size() > 0:
		global_position = _waypoints[0]
		_current_wp_index = 1

func _process(delta: float) -> void:
	if _current_wp_index >= _waypoints.size():
		return

	var was_slowed := _slow_timer > 0.0
	var was_flashing := _hit_flash_timer > 0.0

	_slow_timer = maxf(_slow_timer - delta, 0.0)
	_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
	if _slow_timer <= 0.0:
		_slow_multiplier = 1.0

	var target := _waypoints[_current_wp_index]
	var direction := (target - global_position).normalized()
	var move_distance := speed * _slow_multiplier * delta
	var distance_to_target := global_position.distance_to(target)

	if move_distance >= distance_to_target:
		# 到达当前路径点
		global_position = target
		_current_wp_index += 1
		if _current_wp_index >= _waypoints.size():
			_on_reached_end()
	else:
		global_position += direction * move_distance

	# 移动本身由节点变换处理，无需重绘；仅在减速光圈 / 受击闪白刚结束时重绘
	if (was_slowed and _slow_timer <= 0.0) or (was_flashing and _hit_flash_timer <= 0.0):
		queue_redraw()

## ---- 公共方法 ----

## 受到伤害
func take_damage(damage: int) -> void:
	hp -= damage
	_hit_flash_timer = 0.1
	queue_redraw()
	if hp <= 0:
		_on_killed()

func apply_slow(multiplier: float, duration: float) -> void:
	if duration <= 0.0:
		return
	_slow_multiplier = minf(_slow_multiplier, clampf(multiplier, 0.2, 1.0))
	_slow_timer = maxf(_slow_timer, duration)
	queue_redraw()

func setup(data: Dictionary) -> void:
	enemy_type = String(data.get("type", "grunt"))
	max_hp = int(data.get("hp", max_hp))
	hp = max_hp
	speed = float(data.get("speed", speed))
	reward = int(data.get("reward", reward))
	var color_value = data.get("color", body_color)
	if color_value is Color:
		body_color = color_value

func get_path_progress() -> float:
	if _waypoints.is_empty():
		return 0.0
	if _current_wp_index >= _waypoints.size():
		return float(_waypoints.size())

	var previous_index := _current_wp_index - 1
	if previous_index < 0:
		previous_index = 0
	var segment_start := _waypoints[previous_index]
	var segment_end := _waypoints[_current_wp_index]
	var segment_length := segment_start.distance_to(segment_end)
	if segment_length <= 0.0:
		return float(previous_index)

	var segment_progress := segment_start.distance_to(global_position) / segment_length
	return float(previous_index) + clampf(segment_progress, 0.0, 1.0)

func _get_enemy_art_texture() -> Texture2D:
	if enemy_type in _enemy_art_textures:
		return _enemy_art_textures[enemy_type]
	if not (enemy_type in ENEMY_ART_PATHS):
		return null

	var path := String(ENEMY_ART_PATHS[enemy_type])
	var svg_text := FileAccess.get_file_as_string(path)
	if svg_text.is_empty():
		return null

	var image := Image.new()
	var error := image.load_svg_from_string(svg_text)
	if error != OK:
		return null

	var texture := ImageTexture.create_from_image(image)
	_enemy_art_textures[enemy_type] = texture
	return texture

## ---- 内部方法 ----

## 被击杀
func _on_killed() -> void:
	GameManager.notify_enemy_killed()
	GameManager.add_gold(reward)
	queue_free()

## 到达终点
func _on_reached_end() -> void:
	GameManager.lose_life(1)
	queue_free()

## ---- 绘制美术资源、状态和血条 ----
func _draw() -> void:
	var color: Color

	if hp > max_hp * 0.6:
		color = body_color
	elif hp > max_hp * 0.3:
		color = Color(0.9, 0.8, 0.1)   # 黄：中等
	else:
		color = Color(0.9, 0.2, 0.2)   # 红：危险

	if _hit_flash_timer > 0.0:
		color = color.lerp(Color.WHITE, 0.65)

	var art_texture := _get_enemy_art_texture()
	if art_texture:
		var size := Vector2(44, 44) if enemy_type != "tank" else Vector2(52, 52)
		draw_texture_rect(art_texture, Rect2(-size * 0.5, size), false, color)
	elif enemy_type == "runner":
		var runner_shape := PackedVector2Array([
			Vector2(0, -18), Vector2(18, 0), Vector2(0, 18), Vector2(-18, 0)
		])
		draw_polygon(runner_shape, PackedColorArray([color]))
	else:
		draw_rect(Rect2(-15, -15, 30, 30), color)

	if _slow_timer > 0.0:
		draw_rect(Rect2(-18, -18, 36, 36), Color(0.4, 0.85, 1.0, 0.35), false, 2.0)

	# 血量条背景
	var bar_bg := Rect2(-15, -22, 30, 5)
	draw_rect(bar_bg, Color(0.3, 0.3, 0.3))

	# 血量条前景
	var hp_ratio := float(hp) / float(max_hp)
	var bar_fg := Rect2(-15, -22, 30.0 * hp_ratio, 5)
	draw_rect(bar_fg, Color(0.1, 0.9, 0.1))
