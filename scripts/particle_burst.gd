## 一次性粒子爆发（CPU 粒子，兼容 gl_compatibility，无需外部贴图）
## 粒子贴图在运行时程序化生成（柔和圆点），播放完毕自动销毁
class_name ParticleBurst
extends CPUParticles2D

static var _dot_texture: Texture2D = null

## 配置并立即播放一次粒子爆发
## dir 为零向量时四散；否则朝指定方向以 spread 角度发射
func setup(color_value: Color, amount_value: int, speed_value: float, particle_size: float, life: float, dir: Vector2 = Vector2.ZERO, spread_degrees: float = 180.0) -> void:
	texture = _get_dot_texture()
	emitting = false
	one_shot = true
	explosiveness = 1.0
	local_coords = false
	amount = maxi(amount_value, 1)
	lifetime = life
	color = color_value

	if dir == Vector2.ZERO:
		direction = Vector2(0, -1)
		spread = 180.0
	else:
		direction = dir.normalized()
		spread = spread_degrees

	initial_velocity_min = speed_value * 0.35
	initial_velocity_max = speed_value
	gravity = Vector2(0, 90)
	damping_min = 20.0
	damping_max = 60.0
	scale_amount_min = particle_size * 0.5
	scale_amount_max = particle_size

	# 透明度随生命周期淡出
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	color_ramp = ramp

	finished.connect(queue_free)
	emitting = true

## 生成一张柔和圆点贴图并缓存（首次调用时构建）
static func _get_dot_texture() -> Texture2D:
	if _dot_texture:
		return _dot_texture

	var size := 12
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var max_dist := size * 0.5
	for y in range(size):
		for x in range(size):
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(center) / max_dist
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha * alpha))

	_dot_texture = ImageTexture.create_from_image(image)
	return _dot_texture
