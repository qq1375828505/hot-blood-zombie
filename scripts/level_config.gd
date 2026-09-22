class_name LevelConfig
extends RefCounted
# V1.2 多关卡静态配置：三关名称/场景/波次表/背景色全部数据驱动。
# 普通静态类（非 Autoload），game.gd / level.gd 通过 LevelConfig.get_level(...) 直接读取。

const LEVELS = {
	1: {
		"name": "黄昏町街道",
		"scene": "res://scenes/level1.tscn",
		"waves": 5,
		"wave_config": [
			# 每波：{walkers: int, runners: int, fat: int, interval: float}
			{"walkers": 3, "runners": 0, "fat": 0, "interval": 1.5},
			{"walkers": 4, "runners": 1, "fat": 0, "interval": 1.3},
			{"walkers": 3, "runners": 2, "fat": 0, "interval": 1.2},
			{"walkers": 4, "runners": 2, "fat": 1, "interval": 1.0},
			{"walkers": 5, "runners": 3, "fat": 1, "interval": 0.9},
		],
		"bg_color": Color(0.16, 0.12, 0.22, 1),
	},
	2: {
		"name": "白鹰高中",
		"scene": "res://scenes/level2.tscn",
		"waves": 5,
		"wave_config": [
			{"walkers": 4, "runners": 1, "fat": 0, "interval": 1.4},
			{"walkers": 3, "runners": 3, "fat": 0, "interval": 1.2},
			{"walkers": 4, "runners": 2, "fat": 1, "interval": 1.1},
			{"walkers": 5, "runners": 3, "fat": 1, "interval": 1.0},
			{"walkers": 6, "runners": 3, "fat": 2, "interval": 0.8},
		],
		"bg_color": Color(0.12, 0.14, 0.18, 1),
	},
	3: {
		"name": "暴走族聚集地",
		"scene": "res://scenes/level3.tscn",
		"waves": 6,
		"wave_config": [
			{"walkers": 5, "runners": 2, "fat": 1, "interval": 1.2},
			{"walkers": 4, "runners": 4, "fat": 1, "interval": 1.0},
			{"walkers": 5, "runners": 3, "fat": 2, "interval": 0.9},
			{"walkers": 6, "runners": 4, "fat": 2, "interval": 0.8},
			{"walkers": 7, "runners": 4, "fat": 2, "interval": 0.7},
			{"walkers": 8, "runners": 5, "fat": 3, "interval": 0.6},
		],
		"bg_color": Color(0.18, 0.10, 0.12, 1),
	},
	4: {
		"name": "白岳制药工厂",
		"scene": "res://scenes/level4.tscn",
		"waves": 6,
		"wave_config": [
			# 每波：{walkers: int, runners: int, fat: int, interval: float}
			{"walkers": 5, "runners": 2, "fat": 1, "interval": 1.1},
			{"walkers": 5, "runners": 3, "fat": 2, "interval": 1.0},
			{"walkers": 6, "runners": 4, "fat": 2, "interval": 0.9},
			{"walkers": 6, "runners": 4, "fat": 3, "interval": 0.8},
			{"walkers": 7, "runners": 5, "fat": 3, "interval": 0.7},
			{"walkers": 8, "runners": 5, "fat": 4, "interval": 0.6},
		],
		"bg_color": Color(0.10, 0.12, 0.14, 1),
	},
	5: {
		"name": "终章·最终 Boss 战",
		"scene": "res://scenes/level5.tscn",
		"waves": 3,
		"wave_config": [
			# 前 2 波：精英 + 小怪混合波
			{"walkers": 4, "runners": 3, "fat": 1, "interval": 1.0},
			{"walkers": 5, "runners": 4, "fat": 2, "interval": 0.9},
			# 第 3 波：Boss 波（boss_id 为新增可选字段，原有字段保留）
			{"walkers": 3, "runners": 2, "fat": 1, "interval": 0.8, "boss_id": "final_boss"},
		],
		"bg_color": Color(0.08, 0.08, 0.10, 1),
	},
}


static func get_level(index: int) -> Dictionary:
	return LEVELS.get(index, {})


static func get_wave_config(level_index: int, wave: int) -> Dictionary:
	var lv = get_level(level_index)
	if lv.is_empty():
		return {}
	var wc = lv.get("wave_config", [])
	if wave >= 0 and wave < wc.size():
		return wc[wave]
	return {}


static func get_total_waves(level_index: int) -> int:
	return get_level(level_index).get("waves", 5)
