## 防御塔脚本
## 自动攻击范围内最近的敌人
extends Node2D

## ---- 属性 ----
var attack_damage: int = 10
var attack_range: float = 160.0   # 像素
var attack_cooldown: float = 1.0  # 秒

## ---- 内部状态 ----
var _cooldown_timer: float = 0.0
var _current_target: Node2D = null
var _shot_flash_timer: float = 0.0

## ---- 节点引用 ----
@onready var attack_area: Area2D = $AttackRangeArea

## ---- 生命周期 ----
func _ready() -> void:
	# 配置攻击范围碰撞体
	var shape := CircleShape2D.new()
	shape.radius = attack_range
	attack_area.get_node("CollisionShape2D").shape = shape

func _process(delta: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	_shot_flash_timer = maxf(_shot_flash_timer - delta, 0.0)

	# 清理已销毁的目标
	if _current_target and not is_instance_valid(_current_target):
		_current_target = null

	# 选择目标：优先攻击路径进度最高的敌人
	_select_target()

	# 攻击
	if _current_target and _cooldown_timer <= 0.0:
		_attack(_current_target)
		_cooldown_timer = attack_cooldown

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
	if target.has_method("take_damage"):
		target.call("take_damage", attack_damage)
		_shot_flash_timer = 0.12

## ---- 绘制（用色块代替美术资源） ----
func _draw() -> void:
	# 塔身（蓝色方块）
	var rect := Rect2(-25, -25, 50, 50)
	var body_color := Color(0.2, 0.4, 0.9) if _shot_flash_timer <= 0.0 else Color(1.0, 0.85, 0.25)
	draw_rect(rect, body_color)
	draw_rect(Rect2(-12, -35, 24, 14), Color(0.12, 0.18, 0.35))

	draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(0.35, 0.55, 1.0, 0.18), 1.0)

	# 攻击指示线（指向当前目标）
	if _current_target and is_instance_valid(_current_target):
		var local_target := _current_target.global_position - global_position
		draw_line(Vector2.ZERO, local_target, Color(1, 1, 0.3, 0.7), 2.0)
