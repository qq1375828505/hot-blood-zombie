class_name CombatConfig
extends RefCounted
## 战斗数值中心配置
## 数据来源：River City Rival Showdown 逆向（attack_collisions / hit_vectors / base_characters / waves / kunio_animation_timings）
## 帧→秒换算：60fps 下 1帧 = 1/60 ≈ 0.0167s。hit_stop 档位：0/2/4/5/6/8/10/12/15/20/25 帧。

# ============================================================
# 玩家基础属性（国夫 Kunio）
# ============================================================
const PLAYER := {
	"max_hp": 240.0,		# 逆向: HP=240
	"max_sp": 100.0,		# 逆向: SP=100（预留，后续接能量系统）
	"walk_speed": 220.0,
	"run_speed": 320.0,
	"jump_velocity": -520.0,
	"gravity": 1800.0,
	"max_fall_speed": 900.0,
	"face_offset_x": 24.0,
}

# ============================================================
# 四套攻击的帧数据（单位：秒；原始单位为帧，已按60fps换算）
# 每套攻击分三段：起手(telegraph) → 判定(active) → 收招(recovery)
# 连击：在 recovery 末尾的 cancel_window 内再次按攻击键可衔接下一击
# 逆向参考：起手5~8帧，判定4帧，收招10~15帧
# ============================================================
const ATTACKS := {
	"punch": {
		# 轻拳: damage=6, valid_frames=4, hit_stop=0帧, down_value=10
		"telegraph": 0.10,		# 6帧起手
		"active": 0.067,			# 4帧判定
		"recovery": 0.18,		# 11帧收招
		"cancel_window": 0.05,	# 收招末尾可取消
		"damage": 6.0,			# 逆向: 轻拳伤害6
		"knockback": 120.0,		# 逆向: 轻击退 vecx=2
		"hitstop": 0.0,			# 逆向: hit_stop=0帧（轻拳无顿帧）
		"stagger": 0.15,		# 短硬直
		"hitbox_size": Vector2(50, 60),
		"max_combo": 3,			# 三连拳
	},
	"kick": {
		# 轻踢: damage=9, valid_frames=4, hit_stop=0帧
		# 重踢/飞踢: damage=12~18, valid_frames=4~10, hit_stop=2~5帧
		"telegraph": 0.12,		# 7帧起手
		"active": 0.067,			# 4帧判定
		"recovery": 0.20,		# 12帧收招
		"cancel_window": 0.06,
		"damage": 12.0,			# 逆向: 轻踢9→重踢取中位12
		"knockback": 250.0,		# 逆向: 中击退 vecx=5~6
		"hitstop": 0.033,		# 逆向: hit_stop=2帧
		"stagger": 0.30,
		"hitbox_size": Vector2(70, 70),
		"max_combo": 2,
	},
	"weapon": {
		# 武器攻击: weapon_power=9, throw_power=12
		# 终结技: damage=12+, hit_stop=5帧, down_value=25（击倒）
		"telegraph": 0.13,		# 8帧起手
		"active": 0.083,			# 5帧判定
		"recovery": 0.25,		# 15帧收招
		"cancel_window": 0.04,
		"damage": 12.0,			# 逆向: throw_power=12
		"knockback": 400.0,		# 逆向: 重击浮空 vecx=10
		"hitstop": 0.083,		# 逆向: hit_stop=5帧
		"stagger": 0.55,		# down_value=25 击倒
		"hitbox_size": Vector2(90, 80),
		"max_combo": 1,
	},
	"jump": {
		# 跳跃攻击 = 空中飞踢，对应重踢高位
		"telegraph": 0.05,
		"active": 0.083,			# 5帧判定
		"recovery": 0.0,
		"cancel_window": 0.0,
		"damage": 15.0,			# 逆向: 重踢 damage=12~18 取中
		"knockback": 350.0,		# 逆向: 浮空 vecx=8, vecy=8
		"hitstop": 0.067,		# 逆向: hit_stop=4帧
		"stagger": 0.40,
		"hitbox_size": Vector2(60, 60),
		"max_combo": 1,
	},
}

# ============================================================
# 敌人类型数值（逆向: base_characters + group_overrides）
# 三档: weak(普通) / speed(快速) / heavy(重装)
# 丧尸化修改（对齐 Unity PC 丧尸版）：HP ×2.5，walk/chase 速度 ×0.5
# ============================================================
const ENEMIES := {
	"zombie_normal": {
		# weak: HP=20~60, punch=8~20, kick=8~20, speed=0~5, toughness=10
		"display_name": "普通丧尸",
		"max_hp": 100.0,			# 逆向中位40 ×2.5（丧尸化：HP提升）
		"walk_speed": 30.0,		# 逆向 60 ×0.5（丧尸化：速度减半）
		"chase_speed": 45.0,		# 逆向 90 ×0.5
		"attack_range": 55.0,
		"attack_damage": 12.0,	# 逆向 punch=8~20 取中
		"attack_telegraph": 0.45,
		"attack_active": 0.15,
		"attack_recovery": 0.5,
		"stagger_resist": 0.0,	# toughness=10 → 无硬直抗性
		"knockback_resist": 0.0,
		"touch_damage": 0.0,
		"color": Color(0.35, 0.6, 0.35),
		"collision_radius": 22.0,
	},
	"zombie_fast": {
		# speed: HP=100~150, punch=26~36, kick=28~44, speed=15~20, toughness=14~19
		"display_name": "快速丧尸",
		"max_hp": 300.0,			# 逆向中位120 ×2.5（丧尸化：HP提升）
		"walk_speed": 75.0,		# 逆向 150 ×0.5（丧尸化：速度减半）
		"chase_speed": 100.0,		# 逆向 200 ×0.5
		"attack_range": 50.0,
		"attack_damage": 32.0,	# 逆向 punch=26~36 取中
		"attack_telegraph": 0.30,
		"attack_active": 0.12,
		"attack_recovery": 0.35,
		"stagger_resist": 0.15,	# toughness=14~19 → 15%硬直抗性
		"knockback_resist": 0.10,
		"touch_damage": 0.0,
		"color": Color(0.85, 0.75, 0.2),
		"collision_radius": 18.0,
	},
	"zombie_heavy": {
		# heavy: HP=500~600, punch=58~80, kick=56~82, speed=6~12, toughness=32~48
		"display_name": "重装丧尸",
		"max_hp": 1375.0,			# 逆向中位550 ×2.5（丧尸化：HP提升）
		"walk_speed": 22.5,		# 逆向 45 ×0.5（丧尸化：速度减半）
		"chase_speed": 27.5,		# 逆向 55 ×0.5
		"attack_range": 65.0,
		"attack_damage": 70.0,	# 逆向 punch=58~80 取中
		"attack_telegraph": 0.65,
		"attack_active": 0.20,
		"attack_recovery": 0.80,
		"stagger_resist": 0.50,	# toughness=32~48 → 50%硬直抗性
		"knockback_resist": 0.60,	# 重怪击退抗性
		"touch_damage": 0.0,
		"color": Color(0.5, 0.3, 0.6),
		"collision_radius": 30.0,
	},
}

# ============================================================
# 波次配置（逆向: waves.json）
# 同屏 active_amount=5, 总库存 stock=30, 波次间隔 60s→手游缩至4s
# ============================================================
const WAVES := {
	"wave_interval": 4.0,			# 逆向 60s → 手游缩至4s
	"spawn_interval": 0.6,
	"max_active_enemies": 5,		# 逆向: active_amount=5
	"spawn_margin": 80.0,
	"total_stock": 30,			# 逆向: stock=30
	# 波次表：6波共30只敌人
	"waves": [
		# Wave 1: 5 普通（stock 5）
		[{"type": "zombie_normal", "count": 5}],
		# Wave 2: 5 普通（stock 10）
		[{"type": "zombie_normal", "count": 5}],
		# Wave 3: 3 普通 + 2 快速（stock 15）
		[{"type": "zombie_normal", "count": 3}, {"type": "zombie_fast", "count": 2}],
		# Wave 4: 3 快速 + 2 重装（stock 20）
		[{"type": "zombie_fast", "count": 3}, {"type": "zombie_heavy", "count": 2}],
		# Wave 5: 2 普通 + 3 快速 + 2 重装（stock 27）
		[{"type": "zombie_normal", "count": 2}, {"type": "zombie_fast", "count": 3}, {"type": "zombie_heavy", "count": 2}],
		# Wave 6: 3 重装（stock 30）
		[{"type": "zombie_heavy", "count": 3}],
	],
}

# ============================================================
# 打击手感参数
# ============================================================
const FEEL := {
	"hitstop_global_scale": 1.0,
	"camera_shake_amount": 6.0,
	"camera_shake_duration": 0.15,
	"hit_flash_duration": 0.08,
	"death_fall_duration": 0.6,
	"death_fade_duration": 0.5,
}

# ============================================================
# 场景边界（1280x720，地面在 y≈560）
# ============================================================
const WORLD := {
	"ground_y": 560.0,
	"left_bound": 60.0,
	"right_bound": 1220.0,
	"floor_height": 60.0,
}


# ---- 便捷取值方法 ----
static func get_player() -> Dictionary:
	return PLAYER

static func get_attack(name: String) -> Dictionary:
	return ATTACKS.get(name, {})

static func get_enemy(type: String) -> Dictionary:
	return ENEMIES.get(type, {})

static func get_waves() -> Dictionary:
	return WAVES

static func get_feel() -> Dictionary:
	return FEEL

static func get_world() -> Dictionary:
	return WORLD
