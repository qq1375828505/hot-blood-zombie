extends Node
# V1.2 角色数据 Autoload 单例：角色定义 + P1/P2 选人结果存储
# 注册于 project.godot [autoload] 段

const CHARACTERS := {
	"pompadour": {
		"name": "飞机头主角",
		"desc": "速度/攻击/体力三项均衡，推荐新手",
		"color": Color(1, 0.85, 0.3, 1),
		"speed_mult": 1.0,
		"atk_mult": 1.0,
		"hp_mult": 1.0,
		"jump_mult": 1.0,
		"melee_range_mult": 1.0,
		# ---- V2.2 专属必杀（个人武技）----
		"special_skill": "mach_kick",
		"special_damage": 15,
	},
	"fighter": {
		"name": "格斗专家",
		"desc": "拳脚伤害高、连击更强，但体力略低",
		"color": Color(0.9, 0.3, 0.2, 1),
		"speed_mult": 1.0,
		"atk_mult": 1.3,
		"hp_mult": 0.85,
		"jump_mult": 1.0,
		"melee_range_mult": 1.1,
		"special_skill": "mach_punch",
		"special_damage": 18,
	},
	"sprinter": {
		"name": "疾风飞毛腿",
		"desc": "移动/跳跃速度大幅提升，攻击略低",
		"color": Color(0.3, 0.8, 1.0, 1),
		"speed_mult": 1.4,
		"atk_mult": 0.85,
		"hp_mult": 0.9,
		"jump_mult": 1.25,
		"melee_range_mult": 1.0,
		"special_skill": "tornado_kick",
		"special_damage": 14,
	},
	"tank": {
		"name": "铁壁壮汉",
		"desc": "体力高、抗击打强、近战范围大，但移动慢",
		"color": Color(0.5, 0.5, 0.55, 1),
		"speed_mult": 0.75,
		"atk_mult": 1.1,
		"hp_mult": 1.4,
		"jump_mult": 0.85,
		"melee_range_mult": 1.3,
		"special_skill": "earthquake",
		"special_damage": 12,
	},
	"bosozoku": {
		"name": "暴走族总长",
		"desc": "高攻高速但体力最低（隐藏角色，通关第一章解锁）",
		"color": Color(0.8, 0.2, 0.8, 1),
		"speed_mult": 1.3,
		"atk_mult": 1.4,
		"hp_mult": 0.7,
		"jump_mult": 1.15,
		"melee_range_mult": 1.0,
		"hidden": true,
		# 贵≠强反差：书最贵 8000，但伤害仅 8，且有搞笑弹回演出
		"special_skill": "human_torpedo",
		"special_damage": 8,
	},
}

var selected_p1: String = "pompadour"
var selected_p2: String = "pompadour"
# 隐藏角色解锁开关：V1.2 简化为默认解锁；后续可由 Achievements 单例读取 clear_ch1 成就联动
var unlocked_hidden: bool = true


func _ready() -> void:
	# 预留：从存档 / Achievements 单例读取隐藏角色解锁状态
	var ach := get_node_or_null("/root/Achievements")
	if ach != null and ach.has_method("is_unlocked"):
		unlocked_hidden = ach.is_unlocked("clear_ch1") or unlocked_hidden


func get_character(id: String) -> Dictionary:
	return CHARACTERS.get(id, {})


func get_available_ids() -> Array:
	var ids: Array = []
	for key in CHARACTERS.keys():
		var data: Dictionary = CHARACTERS[key]
		if data.get("hidden", false) and not unlocked_hidden:
			continue
		ids.append(key)
	return ids


func select(player_index: int, char_id: String) -> void:
	if player_index == 1:
		selected_p1 = char_id
	elif player_index == 2:
		selected_p2 = char_id


func get_selected(player_index: int) -> String:
	if player_index == 2:
		return selected_p2
	return selected_p1


func reset() -> void:
	selected_p1 = "pompadour"
	selected_p2 = "pompadour"
