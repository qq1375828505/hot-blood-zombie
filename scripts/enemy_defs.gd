class_name EnemyDefs
extends RefCounted
# V1.3 怪物能力值数据表（数据驱动，不硬编码）
# 能力值体系：玩家裸装=1，叠满buff+合击≈5
#   普通小怪：0.5（基础）~ 3（爆发：疾跑突进/胖子撕咬）
#   精英怪：4 ~ 5
#   Boss：7 ~ 10
# 吸血比例：小怪5% / 精英8% / Boss10%（按造成伤害比例回血，不超过最大血量）

# ---- 普通丧尸定义（与 V1.0 既有数值对齐，ability 为新增标注）----
const NORMAL_ZOMBIES := {
	"walker": {
		"ability": 0.5,
		"hp": 3,
		"damage": 10,
		"speed": 70.0,
		"lifesteal_rate": 0.05,        # 小怪吸血 5%
		"dodge_chance": 0.40,           # 躲避概率 40%（冷却1.5秒）
		"dodge_cooldown": 1.5,
		"super_armor": false,
		"stun_resist": 0.0,
		"burst_ability": 2.0,
		"hit_streak_threshold": 3,      # 连续被命中3次后强制躲避
	},
	"runner": {
		"ability": 0.7,
		"hp": 2,
		"damage": 10,
		"speed": 155.0,
		"lifesteal_rate": 0.05,
		"dodge_chance": 0.40,
		"dodge_cooldown": 1.5,
		"super_armor": false,
		"stun_resist": 0.0,
		"burst_ability": 2.5,            # 疾跑冲锋爆发
		"hit_streak_threshold": 3,
		"dash_telegraph": true,          # 冲锋前摇（红眼）
	},
	"fat": {
		"ability": 1.2,
		"hp": 14,
		"damage": 15,
		"speed": 45.0,
		"lifesteal_rate": 0.05,
		"dodge_chance": 0.40,
		"dodge_cooldown": 1.5,
		"super_armor": false,
		"stun_resist": 0.3,              # 胖子有一定硬直抗性
		"burst_ability": 3.0,            # 撕咬突进爆发
		"hit_streak_threshold": 3,
	},
}

# ---- 精英怪定义（ability 4~5，至少2种）----
const ELITES := {
	"bosozoku_leader": {
		"name": "暴走族干部",
		"ability": 4.5,
		"hp": 60,
		"damage": 20,
		"speed": 130.0,
		"lifesteal_rate": 0.08,          # 精英吸血 8%
		"dodge_chance": 0.50,            # 会躲避玩家子弹
		"dodge_cooldown": 1.2,
		"super_armor": true,              # 霸体帧
		"stun_resist": 0.7,
		"abilities": ["dodge_bullets", "melee_dash"],
		"dash_speed": 420.0,
		"dash_range": 160.0,
		"dash_cooldown": 3.5,
		"dash_damage": 25,
	},
	"zombie_butcher": {
		"name": "丧尸屠夫",
		"ability": 4.0,
		"hp": 90,                         # 高血量
		"damage": 22,
		"speed": 75.0,
		"lifesteal_rate": 0.08,
		"dodge_chance": 0.25,
		"dodge_cooldown": 2.0,
		"super_armor": true,
		"stun_resist": 0.8,
		"abilities": ["swing_aoe", "high_lifesteal"],
		"swing_radius": 100.0,            # 挥击范围攻击
		"swing_damage": 28,
		"swing_cooldown": 2.5,
	},
}

# ---- Boss 定义（ability 7~10，多阶段磨血战）----
const BOSSES := {
	"street_boss": {
		"name": "街头混混头目",
		"ability": 8.5,
		"hp": 400,
		"damage": 25,
		"speed": 95.0,
		"lifesteal_rate": 0.10,           # Boss吸血 10%
		"dodge_chance": 0.15,
		"dodge_cooldown": 2.0,
		"super_armor": true,
		"stun_resist": 0.9,
		"phases": [
			{
				"phase": 1,
				"hp_threshold": 0.66,
				"name": "近战压制",
				"speed_mult": 1.0,
				"damage_mult": 1.0,
				"attacks": ["punch_combo", "body_slam"],
				"summon_minions": false,
			},
			{
				"phase": 2,
				"hp_threshold": 0.33,
				"name": "召唤冲刺",
				"speed_mult": 1.2,
				"damage_mult": 1.2,
				"attacks": ["punch_combo", "dash_charge", "body_slam"],
				"summon_minions": true,
				"summon_interval": 12.0,
				"summon_count": 3,
			},
			{
				"phase": 3,
				"hp_threshold": 0.0,
				"name": "狂暴吸血",
				"speed_mult": 1.5,
				"damage_mult": 1.4,
				"attacks": ["punch_combo", "dash_charge", "body_slam", "lifesteal_frenzy"],
				"summon_minions": true,
				"summon_interval": 10.0,
				"summon_count": 4,
				"lifesteal_mult": 2.0,          # 阶段3吸血强化至20%
			},
		],
		"weak_point": {
			"description": "阶段切换后3秒硬直窗口，伤害×2",
			"stun_duration": 3.0,
			"damage_mult": 2.0,
		},
		"dash_speed": 480.0,
		"dash_range": 220.0,
		"slam_radius": 130.0,
		"slam_damage": 32,
	},
}

# ---- 爆发状态定义（普通小怪可达 2~3 能力）----
const BURST_STATES := {
	"runner_dash": {
		"name": "疾跑冲锋",
		"trigger": "玩家在冲锋范围内且冷却结束",
		"speed_mult": 2.5,
		"damage_mult": 1.5,
		"ability_mult": 2.5,
		"telegraph_time": 0.4,           # 前摇（红眼）
	},
	"fat_lunge": {
		"name": "胖子撕咬突进",
		"trigger": "玩家在突进范围内且冷却结束",
		"speed_mult": 7.0,
		"damage_mult": 1.5,
		"ability_mult": 3.0,
	},
}

# ---- 工具函数 ----
static func get_normal_def(ztype_name: String) -> Dictionary:
	if NORMAL_ZOMBIES.has(ztype_name):
		return NORMAL_ZOMBIES[ztype_name]
	return {}

static func get_elite_def(elite_id: String) -> Dictionary:
	if ELITES.has(elite_id):
		return ELITES[elite_id]
	return {}

static func get_boss_def(boss_id: String) -> Dictionary:
	if BOSSES.has(boss_id):
		return BOSSES[boss_id]
	return {}

static func get_elite_ids() -> Array:
	return ELITES.keys()

static func get_boss_ids() -> Array:
	return BOSSES.keys()

# 能力值→属性复算（用于UI显示或动态生成）
static func estimate_attributes(ability: float) -> Dictionary:
	return {
		"ability": ability,
		"hp_est": int(round(6.0 * ability)),
		"damage_est": int(round(20.0 * ability)),
		"speed_est": clampf(100.0 * ability, 30.0, 300.0),
		"lifesteal_est": clampf(0.05 + ability * 0.006, 0.05, 0.15),
	}
