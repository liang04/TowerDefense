extends Node2D

var speed: float = 560.0
var damage: int = 1
var slow_multiplier: float = 1.0
var slow_duration: float = 0.0
var projectile_color: Color = Color(1.0, 0.85, 0.25)

var _target: Node2D = null
var _last_target_position: Vector2 = Vector2.ZERO
var _hit_effect_scene: PackedScene = preload("res://scenes/hit_effect.tscn")

func setup(start_position: Vector2, target: Node2D, damage_value: int, slow_value: float, slow_time: float, color_value: Color) -> void:
	global_position = start_position
	_target = target
	damage = damage_value
	slow_multiplier = slow_value
	slow_duration = slow_time
	projectile_color = color_value
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
	queue_redraw()

func _hit() -> void:
	if is_instance_valid(_target) and _target.has_method("take_damage"):
		_target.call("take_damage", damage)
		if slow_duration > 0.0 and _target.has_method("apply_slow"):
			_target.call("apply_slow", slow_multiplier, slow_duration)
		GameManager.request_sfx("hit")

	_spawn_hit_effect()
	queue_free()

func _spawn_hit_effect() -> void:
	var effects_container := _get_effects_container()
	if effects_container == null:
		return

	var effect := _hit_effect_scene.instantiate()
	effects_container.add_child(effect)
	effect.call("setup", global_position, projectile_color, 28.0)

func _get_effects_container() -> Node:
	var current := get_parent()
	while current:
		var effects := current.get_node_or_null("Effects")
		if effects:
			return effects
		current = current.get_parent()
	return null

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, projectile_color)
	draw_line(Vector2(-8, 0), Vector2(4, 0), Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.65), 3.0)
