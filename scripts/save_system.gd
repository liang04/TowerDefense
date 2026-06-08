## 存档读写（进度 + 设置）
## 把 ConfigFile 的 I/O 细节从 GameManager 中分离：本类只负责把纯数据读出/写入
## 磁盘，不引用 GameManager；字段的范围校验与到运行时状态的映射由 GameManager 负责。
class_name SaveSystem
extends RefCounted

## 进度存档路径（用户数据目录，跨会话持久化）
const SAVE_PATH := "user://savegame.cfg"
## 设置存档路径（音量/静音/速度/难度，独立于进度存档）
const SETTINGS_PATH := "user://settings.cfg"

## 读取进度；无存档或损坏时返回空字典（调用方据此回退默认）
func load_progress() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return {}
	return {
		"max_unlocked_level": int(config.get_value("progress", "max_unlocked_level", 0)),
		"last_level_index": int(config.get_value("progress", "last_level_index", 0)),
	}

func save_progress(max_unlocked_level: int, last_level_index: int) -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "max_unlocked_level", max_unlocked_level)
	config.set_value("progress", "last_level_index", last_level_index)
	config.save(SAVE_PATH)

## 读取设置；无存档或损坏时返回空字典
func load_settings() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return {}
	return {
		"game_speed_index": int(config.get_value("settings", "game_speed_index", 0)),
		"difficulty_index": int(config.get_value("settings", "difficulty_index", 1)),
		"sound_volume": float(config.get_value("settings", "sound_volume", 1.0)),
		"muted": bool(config.get_value("settings", "muted", false)),
	}

func save_settings(game_speed_index: int, difficulty_index: int, sound_volume: float, muted: bool) -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "game_speed_index", game_speed_index)
	config.set_value("settings", "difficulty_index", difficulty_index)
	config.set_value("settings", "sound_volume", sound_volume)
	config.set_value("settings", "muted", muted)
	config.save(SETTINGS_PATH)
