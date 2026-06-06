extends RefCounted

static func get_levels() -> Array[Dictionary]:
	return [
		{
			"name": "草地练习场",
			"description": "标准花园路线，适合学习基础种植和升级。",
			"starting_gold": 135,
			"starting_lives": 20,
			"background": Color(0.11, 0.2, 0.13),
			"background_image": "res://assets/maps/cartoon_grassland.png",
			"buildable_color": Color(0.18, 0.55, 0.24, 0.22),
			"path_color": Color(0.35, 0.28, 0.2),
			"ambient_color": Color(1.0, 1.0, 0.97),
			"path": [
				Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
				Vector2i(3, 2), Vector2i(3, 3),
				Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3),
				Vector2i(7, 2), Vector2i(7, 1),
				Vector2i(8, 1), Vector2i(9, 1),
				Vector2i(9, 2), Vector2i(9, 3), Vector2i(9, 4), Vector2i(9, 5),
				Vector2i(8, 5), Vector2i(7, 5), Vector2i(6, 5),
				Vector2i(6, 6), Vector2i(6, 7),
				Vector2i(7, 7), Vector2i(8, 7), Vector2i(9, 7), Vector2i(10, 7), Vector2i(11, 7),
			],
			"waves": [
				{"groups": [
					{"count": 5, "interval": 0.9, "type": "grunt", "hp": 30, "speed": 118.0, "reward": 10, "color": Color(0.25, 0.8, 0.25)},
				]},
				{"groups": [
					{"count": 6, "interval": 0.75, "type": "grunt", "hp": 42, "speed": 122.0, "reward": 10, "color": Color(0.25, 0.8, 0.25)},
					{"count": 3, "interval": 0.55, "type": "runner", "hp": 24, "speed": 175.0, "reward": 12, "color": Color(0.95, 0.9, 0.25)},
				]},
				{"groups": [
					{"count": 8, "interval": 0.7, "type": "runner", "hp": 32, "speed": 185.0, "reward": 13, "color": Color(0.95, 0.9, 0.25)},
					{"count": 3, "interval": 1.0, "type": "tank", "hp": 120, "speed": 80.0, "reward": 22, "color": Color(0.62, 0.55, 0.48)},
				]},
				{"groups": [
					{"count": 12, "interval": 0.45, "type": "grunt", "hp": 58, "speed": 130.0, "reward": 11, "color": Color(0.25, 0.8, 0.25)},
					{"count": 4, "interval": 0.8, "type": "tank", "hp": 150, "speed": 85.0, "reward": 24, "color": Color(0.62, 0.55, 0.48)},
				]},
				{"groups": [
					{"count": 8, "interval": 0.5, "type": "runner", "hp": 44, "speed": 195.0, "reward": 14, "color": Color(0.95, 0.9, 0.25)},
					{"count": 6, "interval": 0.8, "type": "tank", "hp": 190, "speed": 90.0, "reward": 28, "color": Color(0.62, 0.55, 0.48)},
					{"count": 8, "interval": 0.45, "type": "grunt", "hp": 75, "speed": 140.0, "reward": 13, "color": Color(0.25, 0.8, 0.25)},
				]},
				{"groups": [
					{"count": 6, "interval": 0.5, "type": "grunt", "hp": 70, "speed": 135.0, "reward": 12, "color": Color(0.25, 0.8, 0.25)},
					{"count": 1, "interval": 1.0, "type": "boss", "hp": 900, "speed": 68.0, "reward": 100, "color": Color(0.5, 0.15, 0.55)},
				]},
			],
		},
		{
			"name": "峡谷回廊",
			"description": "更长的后院路线，僵尸分批更多，适合练习补种和升级。",
			"starting_gold": 190,
			"starting_lives": 18,
			"background": Color(0.13, 0.17, 0.18),
			"background_image": "res://assets/maps/cartoon_canyon.png",
			"buildable_color": Color(0.18, 0.48, 0.4, 0.24),
			"path_color": Color(0.38, 0.31, 0.24),
			"ambient_color": Color(0.88, 0.92, 1.0),
			"path": [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
				Vector2i(4, 1), Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2), Vector2i(1, 2),
				Vector2i(1, 3), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4),
				Vector2i(6, 3), Vector2i(6, 2), Vector2i(7, 2), Vector2i(8, 2), Vector2i(9, 2), Vector2i(10, 2),
				Vector2i(10, 3), Vector2i(10, 4), Vector2i(9, 4), Vector2i(8, 4),
				Vector2i(8, 5), Vector2i(8, 6), Vector2i(9, 6), Vector2i(10, 6), Vector2i(11, 6),
			],
			"waves": [
				{"groups": [
					{"count": 8, "interval": 0.65, "type": "grunt", "hp": 40, "speed": 130.0, "reward": 10, "color": Color(0.25, 0.8, 0.25)},
				]},
				{"groups": [
					{"count": 7, "interval": 0.55, "type": "runner", "hp": 30, "speed": 190.0, "reward": 12, "color": Color(0.95, 0.9, 0.25)},
					{"count": 5, "interval": 0.75, "type": "grunt", "hp": 58, "speed": 135.0, "reward": 12, "color": Color(0.25, 0.8, 0.25)},
				]},
				{"groups": [
					{"count": 6, "interval": 0.9, "type": "tank", "hp": 155, "speed": 90.0, "reward": 24, "color": Color(0.62, 0.55, 0.48)},
					{"count": 8, "interval": 0.45, "type": "runner", "hp": 42, "speed": 205.0, "reward": 14, "color": Color(0.95, 0.9, 0.25)},
					{"count": 4, "interval": 0.8, "type": "armored", "hp": 90, "speed": 95.0, "reward": 18, "armor": 6, "color": Color(0.85, 0.5, 0.2)},
				]},
				{"groups": [
					{"count": 14, "interval": 0.38, "type": "grunt", "hp": 76, "speed": 145.0, "reward": 13, "color": Color(0.25, 0.8, 0.25)},
					{"count": 7, "interval": 0.7, "type": "tank", "hp": 210, "speed": 92.0, "reward": 30, "color": Color(0.62, 0.55, 0.48)},
					{"count": 6, "interval": 0.5, "type": "frostproof", "hp": 55, "speed": 175.0, "reward": 16, "slow_immune": true, "color": Color(0.55, 0.8, 0.95)},
				]},
				{"groups": [
					{"count": 8, "interval": 0.4, "type": "runner", "hp": 50, "speed": 200.0, "reward": 14, "color": Color(0.95, 0.9, 0.25)},
					{"count": 1, "interval": 1.0, "type": "boss", "hp": 1300, "speed": 72.0, "reward": 130, "color": Color(0.5, 0.15, 0.55)},
				]},
			],
		},
		{
			"name": "熔岩急道",
			"description": "路线较短、压力更高，适合练习寒冰花减速和爆裂果集火。",
			"starting_gold": 220,
			"starting_lives": 14,
			"background": Color(0.18, 0.14, 0.12),
			"background_image": "res://assets/maps/cartoon_lava.png",
			"buildable_color": Color(0.42, 0.24, 0.18, 0.26),
			"path_color": Color(0.46, 0.25, 0.16),
			"ambient_color": Color(1.0, 0.85, 0.76),
			"path": [
				Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4),
				Vector2i(3, 3), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2),
				Vector2i(6, 3), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4), Vector2i(9, 4),
				Vector2i(9, 3), Vector2i(9, 2), Vector2i(10, 2), Vector2i(11, 2),
			],
			"waves": [
				{"groups": [
					{"count": 6, "interval": 0.55, "type": "runner", "hp": 32, "speed": 198.0, "reward": 13, "color": Color(0.95, 0.9, 0.25)},
					{"count": 4, "interval": 0.7, "type": "grunt", "hp": 52, "speed": 138.0, "reward": 12, "color": Color(0.25, 0.8, 0.25)},
				]},
				{"groups": [
					{"count": 5, "interval": 0.85, "type": "tank", "hp": 145, "speed": 92.0, "reward": 25, "color": Color(0.62, 0.55, 0.48)},
					{"count": 8, "interval": 0.45, "type": "runner", "hp": 38, "speed": 212.0, "reward": 14, "color": Color(0.95, 0.9, 0.25)},
				]},
				{"groups": [
					{"count": 14, "interval": 0.34, "type": "grunt", "hp": 72, "speed": 148.0, "reward": 13, "color": Color(0.25, 0.8, 0.25)},
					{"count": 4, "interval": 0.7, "type": "tank", "hp": 185, "speed": 96.0, "reward": 29, "color": Color(0.62, 0.55, 0.48)},
				]},
				{"groups": [
					{"count": 10, "interval": 0.38, "type": "runner", "hp": 50, "speed": 220.0, "reward": 16, "color": Color(0.95, 0.9, 0.25)},
					{"count": 5, "interval": 0.7, "type": "armored", "hp": 110, "speed": 98.0, "reward": 20, "armor": 7, "color": Color(0.85, 0.5, 0.2)},
					{"count": 7, "interval": 0.65, "type": "tank", "hp": 230, "speed": 98.0, "reward": 32, "color": Color(0.62, 0.55, 0.48)},
					{"count": 10, "interval": 0.35, "type": "grunt", "hp": 88, "speed": 152.0, "reward": 14, "color": Color(0.25, 0.8, 0.25)},
				]},
				{"groups": [
					{"count": 8, "interval": 0.32, "type": "runner", "hp": 62, "speed": 228.0, "reward": 18, "color": Color(0.95, 0.9, 0.25)},
					{"count": 9, "interval": 0.55, "type": "tank", "hp": 270, "speed": 102.0, "reward": 36, "color": Color(0.62, 0.55, 0.48)},
					{"count": 8, "interval": 0.45, "type": "frostproof", "hp": 70, "speed": 185.0, "reward": 18, "slow_immune": true, "color": Color(0.55, 0.8, 0.95)},
				]},
				{"groups": [
					{"count": 6, "interval": 0.5, "type": "tank", "hp": 200, "speed": 95.0, "reward": 25, "color": Color(0.62, 0.55, 0.48)},
					{"count": 2, "interval": 2.0, "type": "boss", "hp": 1800, "speed": 76.0, "reward": 170, "color": Color(0.5, 0.15, 0.55)},
				]},
			],
		},
	]
