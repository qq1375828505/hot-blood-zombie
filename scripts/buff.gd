extends RefCounted
class_name BuffDefs
# Buff 定义字典：4 种增益，名称 / 持续时间 / 效果说明。
# 实际的激活 / 倒计时 / 倍率结算由 player.gd 中的 active_buffs 管理，
# 这里只集中维护常量，便于 V1.1 扩展新 buff。

# 名称常量
const SPORTS_DRINK := "sports_drink"
const CHILI_RICE := "chili_rice"
const IRON_PIPE := "iron_pipe"
const ARMOR_VEST := "armor_vest"

# 默认持续时间（秒）。game.gd 拾取时传入，也可从这里取。
const DEFAULT_DURATION := {
	"sports_drink": 15.0,
	"chili_rice": 15.0,
	"iron_pipe": 20.0,
	"armor_vest": 20.0,
}

# 文字描述，便于调试 / 后续 UI
const DESCRIPTIONS := {
	"sports_drink": "移动速度 +30%",
	"chili_rice": "攻击伤害 +50%",
	"iron_pipe": "近战范围 +50%",
	"armor_vest": "受到伤害 -50%",
}

# 随机掉落池（丧尸死亡 10% 概率掉落）
const DROP_POOL := ["chili_rice", "iron_pipe", "armor_vest"]
