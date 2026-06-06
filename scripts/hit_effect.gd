class_name HitEffect
extends Node2D

var effect_color: Color = Color(1.0, 0.85, 0.25)
var max_radius: float = 28.0
var lifetime: float = 0.28

var _age: float = 0.0

func setup(position_value: Vector2, color_value: Color, radius_value: float = 28.0) -> void:
	global_position = position_value
	effect_color = color_value
	max_radius = radius_value

func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var ratio := clampf(_age / lifetime, 0.0, 1.0)
	var radius := lerpf(6.0, max_radius, ratio)
	var alpha := 1.0 - ratio
	draw_circle(Vector2.ZERO, radius, Color(effect_color.r, effect_color.g, effect_color.b, alpha * 0.22))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(effect_color.r, effect_color.g, effect_color.b, alpha), 2.0)
