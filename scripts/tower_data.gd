## 植物（防御塔）静态配置与数值公式
## 把"数据 + 纯函数"从 GameManager 的运行时状态中分离：本类不含可变状态，
## 全部为静态查询/公式。GameManager 保留同名公共方法转发到这里，对外 API 不变。
## 新增植物只需改 CONFIGS，植物栏与热键数据驱动、无需改场景。
class_name TowerData
extends RefCounted

## 等级缩放参数（塔实体与 HUD 显示共用，避免公式重复）
const LEVEL_DAMAGE_SCALE_PER_LEVEL := 0.45   # 每级伤害加成比例
const LEVEL_RANGE_BONUS_PER_LEVEL := 14.0    # 每级射程加成（像素）
const LEVEL_COOLDOWN_SCALE_PER_LEVEL := 0.12 # 每级冷却缩减比例
const MIN_COOLDOWN := 0.18                    # 冷却时间下限（秒）

static var CONFIGS: Dictionary = {
	"arrow": {
		"name": "豌豆射手",
		"cost": 45,
		"damage": 9,
		"range": 170.0,
		"cooldown": 0.65,
		"slow_multiplier": 1.0,
		"slow_duration": 0.0,
		"splash_radius": 0.0,
		"color": Color(0.32, 0.72, 0.28),
		"description": "基础输出，便宜，射速快",
	},
	"cannon": {
		"name": "爆裂果",
		"cost": 75,
		"damage": 24,
		"range": 145.0,
		"cooldown": 1.5,
		"slow_multiplier": 1.0,
		"slow_duration": 0.0,
		"splash_radius": 72.0,
		"color": Color(0.92, 0.42, 0.18),
		"description": "高伤害，射速慢，范围溅射",
	},
	"frost": {
		"name": "寒冰花",
		"cost": 60,
		"damage": 5,
		"range": 155.0,
		"cooldown": 0.9,
		"slow_multiplier": 0.55,
		"slow_duration": 1.8,
		"splash_radius": 0.0,
		"color": Color(0.35, 0.82, 0.95),
		"description": "伤害低，可减速僵尸",
	},
	"pepper": {
		"name": "火爆辣椒",
		"cost": 65,
		"damage": 4,
		"range": 150.0,
		"cooldown": 0.8,
		"slow_multiplier": 1.0,
		"slow_duration": 0.0,
		"splash_radius": 0.0,
		"burn_dps": 8.0,
		"burn_duration": 2.5,
		"color": Color(0.95, 0.45, 0.15),
		"description": "直伤低，点燃后持续灼烧（克高血）",
	},
}

## 有序的植物类型列表（供数据驱动的植物栏与热键使用）
static func get_types() -> Array:
	return CONFIGS.keys()

static func get_config(tower_type: String) -> Dictionary:
	if tower_type in CONFIGS:
		return CONFIGS[tower_type]
	return CONFIGS["arrow"]

static func has_type(tower_type: String) -> bool:
	return tower_type in CONFIGS

static func get_cost(tower_type: String) -> int:
	return int(get_config(tower_type)["cost"])

## 按等级缩放后的塔数值（伤害/射程/冷却/减速），塔实体与 HUD 共用此唯一公式
static func get_scaled_stats(tower_type: String, tower_level: int = 1) -> Dictionary:
	var config := get_config(tower_type)
	var level_offset := float(tower_level - 1)
	var damage_scale := 1.0 + level_offset * LEVEL_DAMAGE_SCALE_PER_LEVEL
	var cooldown_scale := 1.0 - level_offset * LEVEL_COOLDOWN_SCALE_PER_LEVEL
	return {
		"damage": int(round(float(config["damage"]) * damage_scale)),
		"range": float(config["range"]) + level_offset * LEVEL_RANGE_BONUS_PER_LEVEL,
		"cooldown": maxf(float(config["cooldown"]) * cooldown_scale, MIN_COOLDOWN),
		"slow_multiplier": float(config["slow_multiplier"]),
		"slow_duration": float(config["slow_duration"]),
		"splash_radius": float(config.get("splash_radius", 0.0)),
		"burn_dps": float(config.get("burn_dps", 0.0)) * damage_scale,
		"burn_duration": float(config.get("burn_duration", 0.0)),
	}

static func get_stats_text(tower_type: String, tower_level: int = 1) -> String:
	var stats := get_scaled_stats(tower_type, tower_level)
	var slow_multiplier := float(stats["slow_multiplier"])
	var slow_duration := float(stats["slow_duration"])
	var splash_radius := float(stats["splash_radius"])
	var burn_dps := float(stats["burn_dps"])
	var burn_duration := float(stats["burn_duration"])
	var parts: Array[String] = [
		"伤害 %d" % int(stats["damage"]),
		"射程 %d" % int(round(float(stats["range"]))),
		"间隔 %.2fs" % float(stats["cooldown"]),
	]

	if splash_radius > 0.0:
		parts.append("溅射 R%d" % int(round(splash_radius)))

	if burn_dps > 0.0 and burn_duration > 0.0:
		parts.append("灼烧 %d/s × %.1fs" % [int(round(burn_dps)), burn_duration])

	if slow_duration > 0.0 and slow_multiplier < 1.0:
		parts.append("减速 %d%% %.1fs" % [int(round((1.0 - slow_multiplier) * 100.0)), slow_duration])

	return " | ".join(parts)
