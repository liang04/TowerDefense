extends Node2D

var speed: float = 560.0
var damage: int = 1
var slow_multiplier: float = 1.0
var slow_duration: float = 0.0
var splash_radius: float = 0.0  # > 0 时为范围溅射，命中点半径内全体受伤
var projectile_color: Color = Color(1.0, 0.85, 0.25)

var _target: Node2D = null
var _last_target_position: Vector2 = Vector2.ZERO
var _hit_effect_scene: PackedScene = preload("res://scenes/hit_effect.tscn")
var _effects_container: Node = null

func setup(start_position: Vector2, target: Node2D, damage_value: int, slow_value: float, slow_time: float, color_value: Color, splash_value: float = 0.0) -> void:
	global_position = start_position
	_target = target
	damage = damage_value
	slow_multiplier = slow_value
	slow_duration = slow_time
	projectile_color = color_value
	splash_radius = splash_value
	if is_instance_valid(_target):
		_last_target_position = _target.global_position
	queue_redraw()

func _process(delta: float) -> void:
	if is_instance_valid(_target):
		_last_target_position = _target.global_position

	var to_target := _last_target_position - global_position
	var distance := to_target.length()
	var step := speed * delta
	if distance <= step or distance <= 4.0:
		global_position = _last_target_position
		_hit()
		return

	global_position += to_target.normalized() * step
	rotation = to_target.angle()

func _hit() -> void:
	if splash_radius > 0.0:
		_apply_splash_damage()
	elif is_instance_valid(_target) and _target.has_method("take_damage"):
		_damage_enemy(_target)
		GameManager.request_sfx("hit")

	_spawn_hit_effect()
	queue_free()

## 命中点半径内的所有敌人都受到伤害（及减速，若有）
func _apply_splash_damage() -> void:
	var hit_any := false
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var enemy := node as Node2D
		if global_position.distance_to(enemy.global_position) > splash_radius:
			continue
		if not enemy.has_method("take_damage"):
			continue
		_damage_enemy(enemy)
		hit_any = true
	if hit_any:
		GameManager.request_sfx("hit")

func _damage_enemy(enemy: Node) -> void:
	enemy.call("take_damage", damage)
	if slow_duration > 0.0 and enemy.has_method("apply_slow"):
		enemy.call("apply_slow", slow_multiplier, slow_duration)

func _spawn_hit_effect() -> void:
	var effects_container := _get_effects_container()
	if effects_container == null:
		return

	# 溅射时爆炸范围与 AoE 半径一致，便于玩家直观感知打击范围
	var effect_radius := splash_radius if splash_radius > 0.0 else 28.0
	var effect := _hit_effect_scene.instantiate()
	effects_container.add_child(effect)
	effect.call("setup", global_position, projectile_color, effect_radius)

func _get_effects_container() -> Node:
	if _effects_container and is_instance_valid(_effects_container):
		return _effects_container
	var current := get_parent()
	while current:
		var effects := current.get_node_or_null("Effects")
		if effects:
			_effects_container = effects
			return effects
		current = current.get_parent()
	return null

func _draw() -> void:
	var body_radius := 7.0 if splash_radius > 0.0 else 5.0
	draw_circle(Vector2.ZERO, body_radius, projectile_color)
	draw_line(Vector2(-8, 0), Vector2(4, 0), Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.65), 3.0)
