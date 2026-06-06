## 精灵帧动画库
##
## 按命名约定从 assets/sprites 自动加载 PNG 帧并构建 SpriteFrames：
##   <category>/<type>_<index>.png   index 从 0 起、连续
##   例：assets/sprites/enemies/grunt_0.png, grunt_1.png ...
##
## - 单帧 → 静态贴图；多帧 → 逐帧动画（走路循环等）。
## - 用 PNG 字节流直接解码，绕过 Godot 导入系统（与项目现有 SVG 加载一致），
##   因此把图片放进目录即可生效，无需在编辑器里导入。
## - 找不到任何帧时返回 null，调用方据此回退到原有渲染（SVG / 程序化绘制）。
class_name SpriteLibrary
extends RefCounted

const ENEMY_DIR := "res://assets/sprites/enemies/"
const TOWER_DIR := "res://assets/sprites/towers/"
const MAX_FRAMES := 16
const ANIM_NAME := "default"

## 每类型动画参数（帧率、显示缩放）；未列出的类型用 DEFAULT_*
const ENEMY_TUNING := {
	"grunt": {"fps": 8.0, "scale": 0.55},
	"runner": {"fps": 12.0, "scale": 0.5},
	"tank": {"fps": 6.0, "scale": 0.65},
}
const TOWER_TUNING := {
	"arrow": {"fps": 6.0, "scale": 0.7},
	"cannon": {"fps": 6.0, "scale": 0.75},
	"frost": {"fps": 6.0, "scale": 0.7},
}
const DEFAULT_FPS := 8.0
const DEFAULT_SCALE := 0.6

## 缓存：cache_key -> SpriteFrames（或 null 表示无素材）
static var _frames_cache: Dictionary = {}

static func build_enemy_frames(enemy_type: String) -> SpriteFrames:
	return _build(ENEMY_DIR, enemy_type)

static func build_tower_frames(tower_type: String) -> SpriteFrames:
	return _build(TOWER_DIR, tower_type)

static func get_enemy_scale(enemy_type: String) -> float:
	return float((ENEMY_TUNING.get(enemy_type, {}) as Dictionary).get("scale", DEFAULT_SCALE))

static func get_tower_scale(tower_type: String) -> float:
	return float((TOWER_TUNING.get(tower_type, {}) as Dictionary).get("scale", DEFAULT_SCALE))

## ---- 内部实现 ----

static func _build(dir: String, type: String) -> SpriteFrames:
	var cache_key := dir + type
	if _frames_cache.has(cache_key):
		return _frames_cache[cache_key]

	var textures := _load_frame_textures(dir, type)
	if textures.is_empty():
		_frames_cache[cache_key] = null
		return null

	var frames := SpriteFrames.new()
	frames.set_animation_loop(ANIM_NAME, true)
	frames.set_animation_speed(ANIM_NAME, _fps_for(dir, type))
	for texture in textures:
		frames.add_frame(ANIM_NAME, texture)

	_frames_cache[cache_key] = frames
	return frames

static func _fps_for(dir: String, type: String) -> float:
	var tuning: Dictionary = ENEMY_TUNING if dir == ENEMY_DIR else TOWER_TUNING
	return float((tuning.get(type, {}) as Dictionary).get("fps", DEFAULT_FPS))

static func _load_frame_textures(dir: String, type: String) -> Array:
	var textures: Array = []
	for i in range(MAX_FRAMES):
		var path := "%s%s_%d.png" % [dir, type, i]
		if not FileAccess.file_exists(path):
			break
		var texture := _load_png(path)
		if texture == null:
			break
		textures.append(texture)
	return textures

static func _load_png(path: String) -> Texture2D:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)
