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
var reward: int = 10         # 击退后的阳光奖励
var body_color: Color = Color(0.2, 0.8, 0.2)

## ---- 内部状态 ----
var _waypoints: PackedVector2Array = []
var _current_wp_index: int = 0
var _slow_timer: float = 0.0
var _slow_multiplier: float = 1.0
var _hit_flash_timer: float = 0.0
var _hit_punch_tween: Tween = null
var _anim: AnimatedSprite2D = null
var _use_sprite: bool = false

## ---- 生命周期 ----
func _ready() -> void:
	add_to_group("enemies")
	_waypoints = GameManager.path_points
	if _waypoints.size() > 0:
		global_position = _waypoints[0]
		_current_wp_index = 1
	var is_boss := enemy_type == "boss"
	if is_boss:
		add_child(SpriteLibrary.make_shadow(26.0, 10.0, 24.0))
	else:
		add_child(SpriteLibrary.make_shadow(15.0, 6.0, 16.0))
	_setup_sprite()
	if is_boss:
		GameManager.notify_boss_incoming()

## 若存在对应 PNG 帧则用 AnimatedSprite2D 渲染，否则回退到 _draw()
func _setup_sprite() -> void:
	var frames := SpriteLibrary.build_enemy_frames(enemy_type)
	if frames == null:
		return
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = frames
	_anim.scale = Vector2.ONE * SpriteLibrary.get_enemy_scale(enemy_type)
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# 置于父节点之后绘制，使血条/减速光圈叠加在精灵之上
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

	if _use_sprite:
		_update_sprite_visual(direction)

	# 移动本身由节点变换处理，无需重绘；仅在减速光圈 / 受击闪白刚结束时重绘
	if (was_slowed and _slow_timer <= 0.0) or (was_flashing and _hit_flash_timer <= 0.0):
		queue_redraw()

## 精灵模式下：按行进方向水平翻转，受击时整体提亮
func _update_sprite_visual(direction: Vector2) -> void:
	if absf(direction.x) > 0.01:
		_anim.flip_h = direction.x < 0.0
	_anim.modulate = Color(1.5, 1.5, 1.5) if _hit_flash_timer > 0.0 else Color.WHITE

## ---- 公共方法 ----

## 受到伤害
func take_damage(damage: int) -> void:
	hp -= damage
	_hit_flash_timer = 0.1
	_play_hit_punch()
	queue_redraw()
	if hp <= 0:
		_on_killed()

## 受击时的缩放打击感：快速放大再回弹
func _play_hit_punch() -> void:
	if _hit_punch_tween and _hit_punch_tween.is_valid():
		_hit_punch_tween.kill()
	scale = Vector2.ONE
	_hit_punch_tween = create_tween()
	_hit_punch_tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.06)
	_hit_punch_tween.tween_property(self, "scale", Vector2.ONE, 0.1)

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
	GameManager.notify_enemy_killed(global_position, reward, body_color)
	GameManager.add_gold(reward)
	queue_free()

## 到达终点
func _on_reached_end() -> void:
	GameManager.lose_life(1)
	queue_free()

## ---- 绘制美术资源、状态和血条 ----
func _draw() -> void:
	# 精灵模式由 AnimatedSprite2D 绘制本体，这里只补充状态层；否则走原渲染
	if not _use_sprite:
		_draw_body()

	if _slow_timer > 0.0:
		draw_rect(Rect2(-18, -18, 36, 36), Color(0.4, 0.85, 1.0, 0.35), false, 2.0)

	# 血量条（Boss 更宽更高、位置上移，以匹配更大的体型）
	var is_boss := enemy_type == "boss"
	var bar_half := 27.0 if is_boss else 15.0
	var bar_h := 6.0 if is_boss else 5.0
	var bar_y := -40.0 if is_boss else -22.0
	draw_rect(Rect2(-bar_half, bar_y, bar_half * 2.0, bar_h), Color(0.3, 0.3, 0.3))
	var hp_ratio := float(hp) / float(max_hp)
	draw_rect(Rect2(-bar_half, bar_y, bar_half * 2.0 * hp_ratio, bar_h), Color(0.1, 0.9, 0.1))

## SVG / 程序化本体绘制（无 PNG 素材时的回退渲染）
func _draw_body() -> void:
	var color: Color

	if hp > max_hp * 0.6:
		color = body_color
	elif hp > max_hp * 0.3:
		color = Color(0.9, 0.8, 0.1)   # 黄：中等
	else:
		color = Color(0.9, 0.2, 0.2)   # 红：危险

	if _hit_flash_timer > 0.0:
		color = color.lerp(Color.WHITE, 0.65)

	if enemy_type == "boss":
		_draw_boss(color)
		return

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

## 僵尸王本体：大号深色躯干 + 王冠尖刺 + 发光双眼
func _draw_boss(color: Color) -> void:
	draw_circle(Vector2.ZERO, 28.0, color.darkened(0.3))
	draw_circle(Vector2.ZERO, 24.0, color)
	draw_circle(Vector2(-2, -3), 11.0, color.lightened(0.22))
	var crown := color.lightened(0.4)
	for i in range(3):
		var cx := float(i - 1) * 12.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 6.0, -22.0), Vector2(cx + 6.0, -22.0), Vector2(cx, -34.0)
		]), crown)
	draw_circle(Vector2(-8, -3), 3.5, Color(1.0, 0.9, 0.2))
	draw_circle(Vector2(8, -3), 3.5, Color(1.0, 0.9, 0.2))
