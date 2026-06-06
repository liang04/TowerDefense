## 飘字：在世界坐标处上浮并淡出的短文本（如击退阳光奖励）
class_name FloatingText
extends Node2D

const LIFETIME := 0.8
const RISE_SPEED := 46.0
const FONT_SIZE := 18

var _text: String = ""
var _color: Color = Color.WHITE
var _age: float = 0.0
var _font: Font = null

func setup(text_value: String, color_value: Color) -> void:
	_text = text_value
	_color = color_value
	_font = ThemeDB.fallback_font
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	position.y -= RISE_SPEED * delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if _text.is_empty() or _font == null:
		return

	var progress := clampf(_age / LIFETIME, 0.0, 1.0)
	var alpha := 1.0 - progress * progress
	var width := _font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var origin := Vector2(-width * 0.5, 0.0)

	# 深色描影提升可读性
	draw_string(_font, origin + Vector2(1, 1), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(0, 0, 0, alpha * 0.6))
	draw_string(_font, origin, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(_color.r, _color.g, _color.b, alpha))
