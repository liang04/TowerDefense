## 敌人脚本
## 沿 GameManager 中定义的路径点移动，到达终点扣玩家生命
extends Node2D

## ---- 属性 ----
var max_hp: int = 30
var hp: int = 30
var speed: float = 120.0     # 像素/秒
var reward: int = 10         # 击杀金币奖励

## ---- 内部状态 ----
var _waypoints: PackedVector2Array = []
var _current_wp_index: int = 0

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

	var target := _waypoints[_current_wp_index]
	var direction := (target - global_position).normalized()
	var move_distance := speed * delta
	var distance_to_target := global_position.distance_to(target)

	if move_distance >= distance_to_target:
		# 到达当前路径点
		global_position = target
		_current_wp_index += 1
		if _current_wp_index >= _waypoints.size():
			_on_reached_end()
	else:
		global_position += direction * move_distance

	queue_redraw()

## ---- 公共方法 ----

## 受到伤害
func take_damage(damage: int) -> void:
	hp -= damage
	if hp <= 0:
		_on_killed()

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

## ---- 内部方法 ----

## 被击杀
func _on_killed() -> void:
	GameManager.add_gold(reward)
	queue_free()

## 到达终点
func _on_reached_end() -> void:
	GameManager.lose_life(1)
	queue_free()

## ---- 绘制（用色块代替美术资源） ----
func _draw() -> void:
	var rect := Rect2(-15, -15, 30, 30)
	var color: Color

	if hp > max_hp * 0.6:
		color = Color(0.2, 0.8, 0.2)   # 绿：健康
	elif hp > max_hp * 0.3:
		color = Color(0.9, 0.8, 0.1)   # 黄：中等
	else:
		color = Color(0.9, 0.2, 0.2)   # 红：危险

	draw_rect(rect, color)

	# 血量条背景
	var bar_bg := Rect2(-15, -22, 30, 5)
	draw_rect(bar_bg, Color(0.3, 0.3, 0.3))

	# 血量条前景
	var hp_ratio := float(hp) / float(max_hp)
	var bar_fg := Rect2(-15, -22, 30.0 * hp_ratio, 5)
	draw_rect(bar_fg, Color(0.1, 0.9, 0.1))
