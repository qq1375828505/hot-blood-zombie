class_name Weapons
extends RefCounted
# 武器定义表（V2.0 外置）：冷却 / 最大弹药（-1 无限）/ 伤害 / 子弹速度
# 从 player.gd 内联 const 抽离，供核心脚本与 DLC 注册表共用。
# 使用 static var 而非 const：GDScript 4.3 中 const 字典在运行时为只读（Variant 标记 read_only），
# 无法通过引用修改内容；static var 允许 DLC 在运行时追加武器，同时保持类级静态存储。

# ---- 基础武器表 ----
# V2.1：pistol 作为无限弹药默认副武器，伤害保持 2（smoke.gd 硬断言 damage==2）。
# 枪械降级通过 machine_gun/shotgun 改为精英/Boss 稀有掉落实现，而非降低手枪数值。
static var WEAPONS := {
	"pistol": {"cooldown": 0.25, "max_ammo": -1, "damage": 2, "speed": 640.0},
	"machine_gun": {"cooldown": 0.08, "max_ammo": 120, "damage": 2, "speed": 900.0},
	"shotgun": {"cooldown": 0.6, "max_ammo": 24, "damage": 1, "speed": 560.0},
	"grenade": {"cooldown": 1.0, "max_ammo": 3, "damage": 8, "speed": 0.0},
}

# ---- V2.1 近战武器表（日用品当武器）----
# damage: 基础伤害 | durability: 耐久（每次命中 -1）| range_mult: 近战范围倍率
# knockback: 击退倍率 | can_block: 是否可格挡（受击伤害 ×0.5，每次格挡耗 2 耐久）
static var MELEE_WEAPONS := {
	"iron_pipe": {"damage": 6, "durability": 15, "range_mult": 1.5, "knockback": 1.5, "can_block": false, "name": "铁管"},
	"tire":      {"damage": 4, "durability": 20, "range_mult": 1.2, "knockback": 2.0, "can_block": false, "name": "轮胎"},
	"trash_lid": {"damage": 3, "durability": 25, "range_mult": 1.0, "knockback": 1.0, "can_block": true,  "name": "垃圾桶盖"},
}


# 返回武器定义，不存在返回 {}
static func get_weapon(name: String) -> Dictionary:
	return WEAPONS.get(name, {})


# 是否存在指定武器
static func has_weapon(name: String) -> bool:
	return WEAPONS.has(name)


# 返回全部武器名数组
static func get_all_weapon_names() -> Array:
	return WEAPONS.keys()


# 向 WEAPONS 表追加/覆盖武器（用于 DLC 追加）
# WEAPONS 为 static var，运行时可直接修改字典内容
static func register_weapon(name: String, def: Dictionary) -> void:
	WEAPONS[name] = def


# ---- V2.1 近战武器查询 ----
# 返回近战武器定义，不存在返回 {}
static func get_melee_weapon(name: String) -> Dictionary:
	return MELEE_WEAPONS.get(name, {})


# 是否存在指定近战武器
static func has_melee_weapon(name: String) -> bool:
	return MELEE_WEAPONS.has(name)
