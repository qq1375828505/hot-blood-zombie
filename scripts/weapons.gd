class_name Weapons
extends RefCounted
# 武器定义表（V2.0 外置）：冷却 / 最大弹药（-1 无限）/ 伤害 / 子弹速度
# 从 player.gd 内联 const 抽离，供核心脚本与 DLC 注册表共用。
# 使用 static var 而非 const：GDScript 4.3 中 const 字典在运行时为只读（Variant 标记 read_only），
# 无法通过引用修改内容；static var 允许 DLC 在运行时追加武器，同时保持类级静态存储。

# ---- 基础武器表 ----
static var WEAPONS := {
	"pistol": {"cooldown": 0.25, "max_ammo": -1, "damage": 2, "speed": 640.0},
	"machine_gun": {"cooldown": 0.08, "max_ammo": 120, "damage": 2, "speed": 900.0},
	"shotgun": {"cooldown": 0.6, "max_ammo": 24, "damage": 1, "speed": 560.0},
	"grenade": {"cooldown": 1.0, "max_ammo": 3, "damage": 8, "speed": 0.0},
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
