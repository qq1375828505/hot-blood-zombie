extends Node
# Economy 单例（Autoload，名称 Economy）— V1.2 模块1：热血经济循环 + 黑市商店
# 全局金币管理、商店商品数据、购买结算、死亡金钱减半、永久技能书升级
# 跨场景持久化：重开时由 game.gd 调用 reset() 清空

# ---- 核心经济变量 ----
var coins: int = 0                       # 当前金币
var total_earned: int = 0                # 累计获得金币（供成就系统读取）
var shop_open: bool = false               # 商店是否处于打开状态

signal coins_changed(new_amount: int)     # 金币数量变化（增减/减半/重置都广播）

# ---- 商店商品数据 ----
# category: ammo(弹药) / gear(装备) / food(食物回复) / skill(永久技能书)
const SHOP_ITEMS := {
	"ammo_mg": {"name": "机枪弹药x60", "price": 50, "category": "ammo", "desc": "机枪弹药+60"},
	"ammo_shotgun": {"name": "霰弹x12", "price": 40, "category": "ammo", "desc": "霰弹弹药+12"},
	"grenade_x3": {"name": "手雷x3", "price": 60, "category": "ammo", "desc": "手雷+3"},
	"armor_vest": {"name": "护甲背心", "price": 100, "category": "gear", "desc": "减伤50%，持续20s"},
	"iron_pipe": {"name": "铁管", "price": 80, "category": "gear", "desc": "近战范围+50%，持续20s"},
	"onigiri": {"name": "饭团", "price": 30, "category": "food", "desc": "回血25"},
	"noodles": {"name": "泡面", "price": 25, "category": "food", "desc": "回血15+能量20"},
	"sports_drink": {"name": "运动饮料", "price": 35, "category": "food", "desc": "移速+30%，持续15s"},
	"skill_combo_plus": {"name": "技能书：连击强化", "price": 200, "category": "skill", "desc": "连击伤害+20%（永久）"},
	"skill_special_boost": {"name": "技能书：必杀强化", "price": 250, "category": "skill", "desc": "必杀伤害+30%（永久）"},
	# ---- V2.2 角色专属必杀书（书店）：购买即解锁该角色个人武技 ----
	"book_mach_kick": {"name": "马赫踢之书", "price": 3000, "category": "skill", "desc": "解锁飞机头专属必杀「马赫踢」", "skill_id": "mach_kick", "char_id": "pompadour"},
	"book_mach_punch": {"name": "马赫拳之书", "price": 3000, "category": "skill", "desc": "解锁格斗专家专属必杀「马赫拳」", "skill_id": "mach_punch", "char_id": "fighter"},
	"book_earthquake": {"name": "大地震击之书", "price": 4000, "category": "skill", "desc": "解锁铁壁壮汉专属必杀「大地震击」", "skill_id": "earthquake", "char_id": "tank"},
	"book_tornado_kick": {"name": "旋风踢之书", "price": 3500, "category": "skill", "desc": "解锁疾风专属必杀「旋风踢」", "skill_id": "tornado_kick", "char_id": "sprinter"},
	"book_human_torpedo": {"name": "人间鱼雷之书", "price": 8000, "category": "skill", "desc": "最贵却最弱？解锁暴走族专属必杀「人间鱼雷」", "skill_id": "human_torpedo", "char_id": "bosozoku"},
}

# ---- 永久技能书状态 ----
var purchased_skills: Dictionary = {}    # key=技能id, value=true（已购买不可重复购买）
var combo_damage_mult: float = 1.0        # 连击伤害倍率（技能书提升，默认1.0）
var special_damage_mult: float = 1.0      # 必杀伤害倍率（技能书提升，默认1.0）

# ---- V2.2 角色专属必杀习得持久化（user://specials.json）----
var unlocked_specials: Dictionary = {}     # key=skill_id（如 mach_kick）, value=true
const SPECIALS_SAVE_PATH := "user://specials.json"

# 商品分类顺序（左侧分类按钮自上而下）
const CATEGORIES: Array = ["ammo", "gear", "food", "skill"]


func _ready() -> void:
	_load_specials()


# ---- V2.2 必杀习得查询/解锁接口 ----
# 由 skill_id（角色的 special_skill 字段）查询是否已习得
func is_special_learned(skill_id: String) -> bool:
	return unlocked_specials.get(skill_id, false)


# 由角色 id 查询其专属必杀是否已习得
func has_special_unlocked(char_id: String) -> bool:
	var cd := get_node_or_null("/root/CharacterData")
	var skill_id := ""
	if cd != null:
		skill_id = str(cd.get_character(char_id).get("special_skill", ""))
	if skill_id == "":
		return false
	return unlocked_specials.get(skill_id, false)


# 解锁某个必杀技并持久化到 user://specials.json
func unlock_special(skill_id: String) -> void:
	if skill_id == "":
		return
	unlocked_specials[skill_id] = true
	_save_specials()


func _save_specials() -> void:
	var data := {"version": 1, "unlocked": unlocked_specials}
	var f := FileAccess.open(SPECIALS_SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()


func _load_specials() -> void:
	unlocked_specials.clear()
	if not FileAccess.file_exists(SPECIALS_SAVE_PATH):
		return
	var f := FileAccess.open(SPECIALS_SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary and parsed.has("unlocked"):
		var ul: Dictionary = parsed["unlocked"]
		for k in ul.keys():
			unlocked_specials[str(k)] = true


# ---- 金币增删 ----
func add_coins(amount: int) -> void:
	coins += amount
	total_earned += amount
	coins_changed.emit(coins)


func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true


# ---- 死亡金钱减半（学热血物语回档）----
func on_player_death() -> void:
	coins = int(floor(coins / 2.0))
	coins_changed.emit(coins)


# ---- 购买结算 ----
# item_id: SHOP_ITEMS 的 key；player: 收货玩家（P1 或最近存活玩家）
# 返回 true=购买成功并已生效；false=商品不存在/金币不足/技能书已拥有
func buy_item(item_id: String, player: Player) -> bool:
	if not SHOP_ITEMS.has(item_id):
		return false
	var item: Dictionary = SHOP_ITEMS[item_id]
	var price: int = int(item["price"])
	var category: String = str(item["category"])
	# 技能书不可重复购买（前置拦截，避免先扣钱再失败）
	if category == "skill" and purchased_skills.has(item_id):
		return false
	if coins < price:
		return false
	spend_coins(price)
	match category:
		"ammo":
			match item_id:
				"ammo_mg":
					player.weapon_ammo["machine_gun"] = int(player.weapon_ammo.get("machine_gun", 0)) + 60
				"ammo_shotgun":
					player.weapon_ammo["shotgun"] = int(player.weapon_ammo.get("shotgun", 0)) + 12
				"grenade_x3":
					player.weapon_ammo["grenade"] = int(player.weapon_ammo.get("grenade", 0)) + 3
			# 统一刷新弹药 HUD（内部 emit ammo_changed / grenade_changed）
			player._refresh_ammo_hud()
		"gear":
			match item_id:
				"armor_vest":
					player.add_buff("armor_vest", 20.0)
				"iron_pipe":
					player.add_buff("iron_pipe", 20.0)
		"food":
			match item_id:
				"onigiri":
					player.heal(25)
				"noodles":
					player.heal(15)
					player.add_energy(20.0)
				"sports_drink":
					player.add_buff("sports_drink", 15.0)
		"skill":
			# 永久升级：记录并提升倍率（实际伤害倍率在 player.gd 未接入，
			# 此处仅维护 Economy 上的接口值，供后续模块/UI 读取）
			purchased_skills[item_id] = true
			match item_id:
				"skill_combo_plus":
					combo_damage_mult = 1.2
				"skill_special_boost":
					special_damage_mult = 1.3
			# ---- V2.2 必杀书：解锁对应角色个人武技（持久化）----
			if item.has("skill_id"):
				unlock_special(str(item["skill_id"]))
	return true


# ---- 查询接口 ----
func get_items_by_category(category: String) -> Array:
	var result: Array = []
	for item_id in SHOP_ITEMS.keys():
		if str(SHOP_ITEMS[item_id]["category"]) == category:
			result.append(item_id)
	return result


func get_categories() -> Array:
	return CATEGORIES.duplicate()


func get_item(item_id: String) -> Dictionary:
	return SHOP_ITEMS.get(item_id, {})


# ---- 重开清空 ----
func reset() -> void:
	coins = 0
	total_earned = 0
	purchased_skills.clear()
	combo_damage_mult = 1.0
	special_damage_mult = 1.0
	shop_open = false
	coins_changed.emit(coins)
