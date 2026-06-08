class_name Projectile
extends Node2D

var speed: float = 560.0
var damage: int = 1
var slow_multiplier: float = 1.0
var slow_duration: float = 0.0
var splash_radius: float = 0.0  # > 0 时为范围溅射，命中点半径内全体受伤
var burn_dps: float = 0.0       # > 0 时命中附加灼烧
var burn_duration: float = 0.0
var projectile_color: Color = Color(1.0, 0.85, 0.25)

var _target: Enemy = null
var _last_target_position: Vector2 = Vector2.ZERO
var _hit_effect_scene: PackedScene = preload("res://scenes/hit_effect.tscn")
var _particle_burst_scene: PackedScene = preload("res://scenes/particle_burst.tscn")
var _effects_container: Node = null
# 用 Node 弱类型而非 ProjectilePool，避免与池脚本形成 class_name 循环依赖
var _pool: Node = null

## 由对象池在创建时注入自身引用，命中后据此回收
func set_pool(pool: Node) -> void:
	_pool = pool

## 从池中取出复用时调用：恢复显示与逐帧处理
func activate() -> void:
	visible = true
	set_process(true)

## 命中后回收时调用：停止显示与处理，清空目标引用
func deactivate() -> void:
	visible = false
	set_process(false)
	_target = null

func setup(start_position: Vector2, target: Enemy, damage_value: int, slow_value: float, slow_time: float, color_value: Color, splash_value: float = 0.0, burn_dps_value: float = 0.0, burn_duration_value: float = 0.0) -> void:
	global_position = start_position
	_target = target
	damage = damage_value
	slow_multiplier = slow_value
	slow_duration = slow_time
	projectile_color = color_value
	splash_radius = splash_value
	burn_dps = burn_dps_value
	burn_duration = burn_duration_value
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
	elif is_instance_valid(_target):
		_damage_enemy(_target)
		GameManager.request_sfx("hit")

	_spawn_hit_effect()
	# 回收进对象池而非销毁；无池时（理论上不会发生）回退到 queue_free
	if _pool:
		_pool.release(self)
	else:
		queue_free()

## 命中点半径内的所有敌人都受到伤害（及减速，若有）
func _apply_splash_damage() -> void:
	var hit_any := false
	for node in get_tree().get_nodes_in_group("enemies"):
		if not (node is Enemy):
			continue
		var enemy := node as Enemy
		if global_position.distance_to(enemy.global_position) > splash_radius:
			continue
		_damage_enemy(enemy)
		hit_any = true
	if hit_any:
		GameManager.request_sfx("hit")

func _damage_enemy(enemy: Enemy) -> void:
	enemy.take_damage(damage)
	if slow_duration > 0.0:
		enemy.apply_slow(slow_multiplier, slow_duration)
	if burn_dps > 0.0 and burn_duration > 0.0:
		enemy.apply_burn(burn_dps, burn_duration)

func _spawn_hit_effect() -> void:
	var effects_container := _get_effects_container()
	if effects_container == null:
		return

	# 溅射时爆炸范围与 AoE 半径一致，便于玩家直观感知打击范围
	var effect_radius := splash_radius if splash_radius > 0.0 else 28.0
	var effect := _hit_effect_scene.instantiate() as HitEffect
	effects_container.add_child(effect)
	effect.setup(global_position, projectile_color, effect_radius)

	# 命中爆炸粒子：溅射弹更大更密
	var is_splash := splash_radius > 0.0
	var burst := _particle_burst_scene.instantiate() as ParticleBurst
	burst.global_position = global_position
	effects_container.add_child(burst)
	burst.setup(projectile_color, 18 if is_splash else 8, 180.0 if is_splash else 130.0, 7.0 if is_splash else 4.5, 0.45)

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
